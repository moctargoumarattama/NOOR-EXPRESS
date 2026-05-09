import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_messages.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_error.dart';
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
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage: AppMessages.driverRidesAvailableLoadFailed,
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
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage: AppMessages.driverRidesLoadFailed,
        ),
      );
    }
  }

  Future<DriverRide?> fetchActiveRide() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/ride-requests/active',
      );

      final payload = response.data;
      if (payload == null || payload.isEmpty) {
        return null;
      }

      return DriverRide.fromJson(payload);
    } on DioException catch (error) {
      throw DriverRideFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage: AppMessages.driverActiveRideLoadFailed,
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
        throw const DriverRideFailure(AppMessages.driverRideRejectFailed);
      }

      return DriverRide.fromJson(payload);
    } on DioException catch (error) {
      throw DriverRideFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage: AppMessages.driverRideRejectUnavailable,
        ),
      );
    }
  }
}

final driverRidesRepositoryProvider = Provider<DriverRidesRepository>((ref) {
  return DriverRidesRepository(apiClient: ref.watch(apiClientProvider));
});
