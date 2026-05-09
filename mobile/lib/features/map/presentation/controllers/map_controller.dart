import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/location/device_location_service.dart';
import '../../../../core/models/realtime_driver_position.dart';
import '../../data/map_repository.dart';
import '../../data/models/map_point.dart';
import '../../data/models/realtime_driver_marker.dart';

enum MapMode {
  client,
  driver,
}

class MapState {
  const MapState({
    required this.mode,
    required this.accessState,
    required this.drivers,
    required this.isLoading,
    required this.isRefreshingDrivers,
    required this.isTrackingPosition,
    this.currentPosition,
    this.errorMessage,
  });

  const MapState.initial(MapMode mode)
      : this(
          mode: mode,
          accessState: DeviceLocationAccessState.initial,
          drivers: const [],
          isLoading: false,
          isRefreshingDrivers: false,
          isTrackingPosition: false,
        );

  final MapMode mode;
  final DeviceLocationAccessState accessState;
  final MapPoint? currentPosition;
  final List<RealtimeDriverMarker> drivers;
  final bool isLoading;
  final bool isRefreshingDrivers;
  final bool isTrackingPosition;
  final String? errorMessage;

  MapState copyWith({
    DeviceLocationAccessState? accessState,
    MapPoint? currentPosition,
    List<RealtimeDriverMarker>? drivers,
    bool? isLoading,
    bool? isRefreshingDrivers,
    bool? isTrackingPosition,
    String? errorMessage,
    bool clearCurrentPosition = false,
    bool clearErrorMessage = false,
  }) {
    return MapState(
      mode: mode,
      accessState: accessState ?? this.accessState,
      currentPosition:
          clearCurrentPosition ? null : currentPosition ?? this.currentPosition,
      drivers: drivers ?? this.drivers,
      isLoading: isLoading ?? this.isLoading,
      isRefreshingDrivers: isRefreshingDrivers ?? this.isRefreshingDrivers,
      isTrackingPosition: isTrackingPosition ?? this.isTrackingPosition,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class MapController extends StateNotifier<MapState> {
  static const Duration _driversRefreshInterval = Duration(seconds: 25);

  MapController({
    required MapMode mode,
    required DeviceLocationService locationService,
    required MapRepository repository,
  })  : _locationService = locationService,
        _repository = repository,
        super(MapState.initial(mode));

  final DeviceLocationService _locationService;
  final MapRepository _repository;

  StreamSubscription<DevicePosition>? _positionSubscription;
  Timer? _refreshTimer;

  Future<void> start() async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);

    final accessState = await _requestLivePosition();
    if (state.mode == MapMode.client) {
      await refreshDrivers();
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(_driversRefreshInterval, (_) {
        refreshDrivers(silent: true);
      });
    }

    state = state.copyWith(
      isLoading: false,
      accessState: accessState,
      isTrackingPosition: accessState == DeviceLocationAccessState.granted,
    );
  }

  Future<void> refreshDrivers({bool silent = false}) async {
    if (state.mode != MapMode.client) {
      return;
    }

    if (state.isRefreshingDrivers) {
      return;
    }

    state = state.copyWith(
      isRefreshingDrivers: true,
      clearErrorMessage: !silent,
    );

    try {
      final position = state.currentPosition;
      final drivers = position == null
          ? await _repository.fetchConnectedDrivers()
          : await _repository.fetchNearbyDrivers(
              latitude: position.latitude,
              longitude: position.longitude,
            );
      state = state.copyWith(
        drivers: drivers,
        isRefreshingDrivers: false,
        clearErrorMessage: true,
      );
    } on MapRepositoryFailure catch (error) {
      state = state.copyWith(
        isRefreshingDrivers: false,
        errorMessage: error.message,
      );
    }
  }

  void applyDriverPositionUpdate(RealtimeDriverPosition update) {
    if (state.mode != MapMode.client) {
      return;
    }

    final marker = RealtimeDriverMarker.fromRealtimePosition(update);
    final nextDrivers = [...state.drivers];
    final index = nextDrivers.indexWhere(
      (driver) => driver.driverId == marker.driverId,
    );

    if (index >= 0) {
      nextDrivers[index] = marker;
    } else {
      nextDrivers.add(marker);
    }

    state = state.copyWith(drivers: nextDrivers);
  }

  Future<void> openAppSettings() async {
    await _locationService.openAppSettings();
  }

  Future<void> openLocationSettings() async {
    await _locationService.openLocationSettings();
  }

  Future<void> stop() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    state = MapState.initial(state.mode);
  }

  Future<DeviceLocationAccessState> _requestLivePosition() async {
    state = state.copyWith(
      accessState: DeviceLocationAccessState.requesting,
      clearErrorMessage: true,
    );

    final accessState = await _locationService.ensurePermission();
    if (accessState != DeviceLocationAccessState.granted) {
      final message = switch (accessState) {
        DeviceLocationAccessState.denied =>
          'La permission de localisation est necessaire pour afficher la carte live.',
        DeviceLocationAccessState.deniedForever =>
          'La localisation est bloquee. Ouvre les reglages pour activer le tracking live.',
        DeviceLocationAccessState.serviceDisabled =>
          'Le service de localisation est desactive sur cet appareil.',
        _ => 'Impossible d activer la localisation pour le moment.',
      };
      state = state.copyWith(
        accessState: accessState,
        clearCurrentPosition: true,
        isTrackingPosition: false,
        errorMessage: message,
      );
      return accessState;
    }

    final currentPosition = await _locationService.getCurrentPosition();
    if (currentPosition != null) {
      state = state.copyWith(
        currentPosition: MapPoint(
          latitude: currentPosition.latitude,
          longitude: currentPosition.longitude,
          accuracyMeters: currentPosition.accuracyMeters,
        ),
      );
    }

    await _positionSubscription?.cancel();
    _positionSubscription = _locationService.watchPosition().listen((position) {
      state = state.copyWith(
        currentPosition: MapPoint(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracyMeters,
        ),
        isTrackingPosition: true,
        accessState: DeviceLocationAccessState.granted,
      );
    });

    return DeviceLocationAccessState.granted;
  }
}

final mapControllerProvider =
    StateNotifierProvider.autoDispose.family<MapController, MapState, MapMode>(
  (ref, mode) {
    final controller = MapController(
      mode: mode,
      locationService: ref.watch(deviceLocationServiceProvider),
      repository: ref.watch(mapRepositoryProvider),
    );
    ref.onDispose(controller.stop);
    return controller;
  },
);
