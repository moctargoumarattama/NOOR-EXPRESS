import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/location/location_service.dart';
import '../../data/datasources/address_datasource.dart';
import '../../data/models/address_model.dart';
import '../../domain/entities/address_result.dart';

class AddressSearchState {
  const AddressSearchState({
    required this.query,
    required this.results,
    required this.favorites,
    required this.recents,
    required this.isLoading,
    required this.isResolvingCurrentLocation,
    this.errorMessage,
  });

  const AddressSearchState.initial()
      : this(
          query: '',
          results: AddressModel.knownNiameyZones,
          favorites: const [],
          recents: const [],
          isLoading: false,
          isResolvingCurrentLocation: false,
        );

  final String query;
  final List<AddressResult> results;
  final List<AddressResult> favorites;
  final List<AddressResult> recents;
  final bool isLoading;
  final bool isResolvingCurrentLocation;
  final String? errorMessage;

  AddressSearchState copyWith({
    String? query,
    List<AddressResult>? results,
    List<AddressResult>? favorites,
    List<AddressResult>? recents,
    bool? isLoading,
    bool? isResolvingCurrentLocation,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AddressSearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      favorites: favorites ?? this.favorites,
      recents: recents ?? this.recents,
      isLoading: isLoading ?? this.isLoading,
      isResolvingCurrentLocation:
          isResolvingCurrentLocation ?? this.isResolvingCurrentLocation,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AddressSearchController extends StateNotifier<AddressSearchState> {
  AddressSearchController({
    required AddressDatasource datasource,
    required LocationService locationService,
  })  : _datasource = datasource,
        _locationService = locationService,
        super(const AddressSearchState.initial());

  final AddressDatasource _datasource;
  final LocationService _locationService;
  Timer? _debounce;

  Future<void> loadRecents() async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(_recentKey) ?? const [];
    final recents =
        rawItems.map(_decodeRecent).whereType<AddressModel>().toList();
    state = state.copyWith(recents: recents, clearError: true);
  }

  Future<void> loadFavorites() async {
    try {
      final favorites = await _datasource.fetchSavedAddresses();
      state = state.copyWith(
        favorites: favorites,
        clearError: true,
      );
    } on AddressSearchFailure catch (error) {
      state = state.copyWith(
        favorites: const [],
        errorMessage: error.message,
      );
    }
  }

  void search(String query) {
    _debounce?.cancel();
    final cleaned = query.trim();
    state = state.copyWith(query: query, clearError: true);
    if (cleaned.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        results: AddressModel.knownNiameyZones,
      );
      return;
    }

    state = state.copyWith(isLoading: true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final results = await _datasource.search(cleaned);
        state = state.copyWith(
          results: results,
          isLoading: false,
          clearError: true,
        );
      } on AddressSearchFailure catch (error) {
        state = state.copyWith(
          results: _fallback(cleaned),
          isLoading: false,
          errorMessage: error.message,
        );
      }
    });
  }

  Future<AddressResult?> currentLocation() async {
    state = state.copyWith(isResolvingCurrentLocation: true, clearError: true);
    final location = await _locationService.getCurrentPosition(
      accuracy: LocationAccuracy.high,
      timeout: const Duration(seconds: 12),
    );

    if (location case LocationSuccess<Position>(value: final position)) {
      try {
        final address = await _datasource.reverse(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        state = state.copyWith(
          isResolvingCurrentLocation: false,
          clearError: true,
        );
        await saveRecent(address);
        return address;
      } on AddressSearchFailure catch (error) {
        final fallback = _currentGpsAddress(
          latitude: position.latitude,
          longitude: position.longitude,
          displayName: 'Adresse exacte indisponible - GPS utilise',
        );
        state = state.copyWith(
          isResolvingCurrentLocation: false,
          errorMessage: error.message,
        );
        await saveRecent(fallback);
        return fallback;
      }
    }

    if (location case LocationError<Position>(failure: final failure)) {
      final fallback = _niameyFallbackCurrentLocation(failure.message);
      state = state.copyWith(
        isResolvingCurrentLocation: false,
        errorMessage: failure.message,
      );
      await saveRecent(fallback);
      return fallback;
    }

    final fallback = _niameyFallbackCurrentLocation(
      'Position GPS indisponible.',
    );
    state = state.copyWith(isResolvingCurrentLocation: false);
    await saveRecent(fallback);
    return fallback;
  }

  Future<void> saveRecent(AddressResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final next = [
      AddressModel.fromEntity(result),
      ...state.recents
          .where((item) => item.name != result.name)
          .map(AddressModel.fromEntity),
    ].take(5).toList();
    await prefs.setStringList(
      _recentKey,
      next.map((item) => jsonEncode(item.toJson())).toList(),
    );
    state = state.copyWith(recents: next);
  }

  Future<void> addFavorite({
    required AddressResult address,
    required String label,
  }) async {
    final trimmedLabel = label.trim();
    if (trimmedLabel.isEmpty) {
      throw const AddressSearchFailure('Le label du favori est obligatoire.');
    }
    final created = await _datasource.createSavedAddress(
      label: trimmedLabel,
      address: address,
    );
    final nextFavorites = [
      created,
      ...state.favorites.where(
        (item) =>
            item.name.toLowerCase() != created.name.toLowerCase() ||
            item.displayName.toLowerCase() != created.displayName.toLowerCase(),
      ),
    ];
    state = state.copyWith(
      favorites: nextFavorites,
      clearError: true,
    );
  }

  List<AddressResult> _fallback(String query) {
    final needle = query.toLowerCase();
    final zones = AddressModel.knownNiameyZones
        .where((zone) => zone.name.toLowerCase().contains(needle))
        .toList();
    return zones.isEmpty ? AddressModel.knownNiameyZones : zones;
  }

  AddressModel _currentGpsAddress({
    required double latitude,
    required double longitude,
    required String displayName,
  }) {
    return AddressModel(
      name: 'Ma position actuelle',
      displayName: displayName,
      latitude: latitude,
      longitude: longitude,
      type: 'current_location',
    );
  }

  AddressModel _niameyFallbackCurrentLocation(String reason) {
    return AddressModel(
      name: 'Niamey centre',
      displayName: '$reason Position approximative utilisee.',
      latitude: 13.5137,
      longitude: 2.1098,
      type: 'current_location',
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  AddressModel? _decodeRecent(String rawItem) {
    try {
      final decoded = jsonDecode(rawItem);
      if (decoded is! Map) {
        return null;
      }
      return AddressModel.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }
}

const _recentKey = 'noor_recent_addresses';

final addressSearchControllerProvider = StateNotifierProvider.autoDispose<
    AddressSearchController, AddressSearchState>((ref) {
  return AddressSearchController(
    datasource: ref.watch(addressDatasourceProvider),
    locationService: ref.watch(locationServiceProvider),
  );
});
