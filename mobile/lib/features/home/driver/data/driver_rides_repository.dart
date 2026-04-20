import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import 'models/driver_ride.dart';

class DriverRideFailure implements Exception {
  const DriverRideFailure(this.message);

  final String message;
}

class DriverRidesRepository {
  DriverRidesRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<DriverRide>> fetchAvailableRides() async {
    try {
      final response = await _apiClient.dio.get<List<dynamic>>(
        '/ride-requests/available',
      );

      final rides = response.data ?? const [];
      return rides
          .whereType<Map<String, dynamic>>()
          .map(DriverRide.fromJson)
          .toList();
    } on DioException catch (error) {
      throw DriverRideFailure(
        _readErrorMessage(
          error,
          fallbackMessage: 'Impossible de charger les demandes disponibles.',
        ),
      );
    }
  }

  Future<List<DriverRide>> fetchMyRides({
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final response = await _apiClient.dio.get<List<dynamic>>(
        '/ride-requests/driver/me',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
      );

      final rides = response.data ?? const [];
      return rides
          .whereType<Map<String, dynamic>>()
          .map(DriverRide.fromJson)
          .toList();
    } on DioException catch (error) {
      throw DriverRideFailure(
        _readErrorMessage(
          error,
          fallbackMessage: 'Impossible de charger les courses driver.',
        ),
      );
    }
  }

  Future<DriverRide> acceptRide(int rideId) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/ride-requests/$rideId/accept',
      );

      final payload = response.data;
      if (payload == null) {
        throw const DriverRideFailure('Acceptation impossible.');
      }

      return DriverRide.fromJson(payload);
    } on DioException catch (error) {
      throw DriverRideFailure(
        _readErrorMessage(
          error,
          fallbackMessage: 'Impossible d accepter cette course.',
        ),
      );
    }
  }

  Future<DriverRide> rejectRide(int rideId, {String? reason}) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/ride-requests/$rideId/reject',
        data: {'reason': reason},
      );

      final payload = response.data;
      if (payload == null) {
        throw const DriverRideFailure('Refus impossible.');
      }

      return DriverRide.fromJson(payload);
    } on DioException catch (error) {
      throw DriverRideFailure(
        _readErrorMessage(
          error,
          fallbackMessage: 'Impossible de refuser cette course.',
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

final driverRidesRepositoryProvider = Provider<DriverRidesRepository>((ref) {
  return DriverRidesRepository(apiClient: ref.watch(apiClientProvider));
});
