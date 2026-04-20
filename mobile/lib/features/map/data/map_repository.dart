import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'models/realtime_driver_marker.dart';

class MapRepositoryFailure implements Exception {
  const MapRepositoryFailure(this.message);

  final String message;
}

class MapRepository {
  MapRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<RealtimeDriverMarker>> fetchConnectedDrivers() async {
    try {
      final response =
          await _apiClient.dio.get<List<dynamic>>('/realtime/drivers');
      final drivers = response.data ?? const [];
      return drivers
          .whereType<Map<String, dynamic>>()
          .map(RealtimeDriverMarker.fromJson)
          .toList();
    } on DioException catch (error) {
      throw MapRepositoryFailure(
        _readErrorMessage(
          error,
          fallbackMessage: 'Impossible de charger les drivers en direct.',
        ),
      );
    }
  }

  Future<List<RealtimeDriverMarker>> fetchNearbyDrivers({
    required double latitude,
    required double longitude,
    double maxDistanceKm = 5,
  }) async {
    try {
      final response = await _apiClient.dio.get<List<dynamic>>(
        '/realtime/drivers/nearby',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'max_distance_km': maxDistanceKm,
        },
      );
      final drivers = response.data ?? const [];
      return drivers
          .whereType<Map<String, dynamic>>()
          .map(RealtimeDriverMarker.fromJson)
          .toList();
    } on DioException catch (error) {
      throw MapRepositoryFailure(
        _readErrorMessage(
          error,
          fallbackMessage: 'Impossible de charger les drivers proches.',
        ),
      );
    }
  }

  String _readErrorMessage(
    DioException error, {
    required String fallbackMessage,
  }) {
    final data = error.response?.data;

    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
    }

    return fallbackMessage;
  }
}

final mapRepositoryProvider = Provider<MapRepository>((ref) {
  return MapRepository(apiClient: ref.watch(apiClientProvider));
});
