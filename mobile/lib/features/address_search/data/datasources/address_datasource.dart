import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/address_result.dart';
import '../models/address_model.dart';

class AddressSearchFailure implements Exception {
  const AddressSearchFailure(this.message);

  final String message;
}

class AddressDatasource {
  AddressDatasource({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<AddressModel>> search(String query, {int limit = 5}) async {
    try {
      final response = await _apiClient.dio.get<List<dynamic>>(
        '/geocoding/search',
        queryParameters: {'q': query, 'limit': limit},
      );
      final results = response.data
              ?.whereType<Map<String, dynamic>>()
              .map(AddressModel.fromJson)
              .toList() ??
          const <AddressModel>[];
      return results.isEmpty
          ? AddressModel.knownNiameyZones.take(limit).toList()
          : results;
    } on DioException catch (error) {
      throw AddressSearchFailure(_message(error));
    }
  }

  Future<AddressModel> reverse({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/geocoding/reverse',
        queryParameters: {'lat': latitude, 'lng': longitude},
      );
      return AddressModel.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw AddressSearchFailure(_message(error));
    }
  }

  Future<List<AddressModel>> fetchSavedAddresses() async {
    try {
      final response =
          await _apiClient.dio.get<List<dynamic>>('/users/me/addresses');
      final rawItems = response.data ?? const [];
      return rawItems
          .whereType<Map>()
          .map((item) => _savedAddressFromJson(Map<String, dynamic>.from(item)))
          .whereType<AddressModel>()
          .toList(growable: false);
    } on DioException catch (error) {
      throw AddressSearchFailure(_message(error));
    }
  }

  Future<AddressModel> createSavedAddress({
    required String label,
    required AddressResult address,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/users/me/addresses',
        data: {
          'label': label,
          'lat': address.latitude,
          'lon': address.longitude,
          'address_display': address.displayName,
        },
      );
      final payload = response.data ?? const <String, dynamic>{};
      final savedAddress = _savedAddressFromJson(payload);
      if (savedAddress == null) {
        throw const AddressSearchFailure(
          'Adresse favorite invalide retournee par le serveur.',
        );
      }
      return savedAddress;
    } on DioException catch (error) {
      throw AddressSearchFailure(_message(error));
    }
  }

  String _message(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
    }
    return 'Recherche adresse impossible pour le moment.';
  }

  AddressModel? _savedAddressFromJson(Map<String, dynamic> json) {
    final rawLat = json['lat'];
    final rawLon = json['lon'];
    final label = (json['label'] as String?)?.trim();
    final addressDisplay = (json['address_display'] as String?)?.trim();
    if (rawLat is! num ||
        rawLon is! num ||
        label == null ||
        label.isEmpty ||
        addressDisplay == null ||
        addressDisplay.isEmpty) {
      return null;
    }
    return AddressModel(
      name: label,
      displayName: addressDisplay,
      latitude: rawLat.toDouble(),
      longitude: rawLon.toDouble(),
      type: 'favorite',
    );
  }
}

final addressDatasourceProvider = Provider<AddressDatasource>((ref) {
  return AddressDatasource(apiClient: ref.watch(apiClientProvider));
});
