import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_error.dart';
import 'models/client_ride.dart';

class ClientRideFailure implements Exception {
  const ClientRideFailure(this.message);

  final String message;
}

class ClientRidesRepository {
  ClientRidesRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<ClientRide>> fetchMyRides({
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final response = await _apiClient.dio.get<List<dynamic>>(
        '/ride-requests/client/me',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
      );

      final rides = response.data ?? const [];
      return rides
          .whereType<Map<String, dynamic>>()
          .map(ClientRide.fromJson)
          .toList();
    } on DioException catch (error) {
      throw ClientRideFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage: 'Impossible de charger tes courses.',
        ),
      );
    }
  }

  Future<ClientRide> createRide(RideRequestCreateInput input) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/ride-requests/',
        data: input.toJson(),
      );

      final payload = response.data;
      if (payload == null) {
        throw const ClientRideFailure('Creation de course impossible.');
      }

      return ClientRide.fromJson(payload);
    } on DioException catch (error) {
      throw ClientRideFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage: 'Creation de course impossible pour le moment.',
        ),
      );
    }
  }

  Future<PriceEstimate> getPriceEstimate({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/pricing/estimate',
        queryParameters: {
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          'dropoff_lat': dropoffLat,
          'dropoff_lng': dropoffLng,
        },
      );
      final payload = response.data;
      if (payload == null) {
        throw const ClientRideFailure('Estimation du prix impossible.');
      }
      return PriceEstimate.fromJson(payload);
    } on DioException catch (error) {
      throw ClientRideFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage: 'Estimation du prix impossible pour le moment.',
        ),
      );
    }
  }
}

final clientRidesRepositoryProvider = Provider<ClientRidesRepository>((ref) {
  return ClientRidesRepository(apiClient: ref.watch(apiClientProvider));
});
