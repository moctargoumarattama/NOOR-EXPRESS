import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
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
}

final addressDatasourceProvider = Provider<AddressDatasource>((ref) {
  return AddressDatasource(apiClient: ref.watch(apiClientProvider));
});
