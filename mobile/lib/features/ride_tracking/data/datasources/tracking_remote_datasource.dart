import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_error.dart';

class TrackingRemoteFailure implements Exception {
  const TrackingRemoteFailure(this.message);

  final String message;
}

class TrackingRemoteDatasource {
  TrackingRemoteDatasource({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> fetchClientRides() async {
    return _fetchRideList('/ride-requests/client/me');
  }

  Future<List<Map<String, dynamic>>> fetchDriverRides() async {
    return _fetchRideList('/ride-requests/driver/me');
  }

  Future<Map<String, dynamic>?> fetchActiveRide() async {
    final payload = await _fetchMap('/ride-requests/active');
    return payload.isEmpty ? null : payload;
  }

  Future<Map<String, dynamic>> fetchUser(int userId) async {
    return _fetchMap('/users/$userId');
  }

  Future<double?> fetchDriverRating(int driverId) async {
    final payload = await _fetchMap('/ride-requests/stats/driver/$driverId');
    return (payload['average_rating_from_clients'] as num?)?.toDouble();
  }

  Future<Map<String, dynamic>> cancelRide(int rideId) {
    return _post('/ride-requests/$rideId/cancel',
        data: const {'reason': 'Annulee depuis le tracking'});
  }

  Future<Map<String, dynamic>> markArrived(int rideId) {
    return _post('/ride-requests/$rideId/arrive');
  }

  Future<Map<String, dynamic>> startRide(int rideId) {
    return _post('/ride-requests/$rideId/start');
  }

  Future<Map<String, dynamic>> completeRide(int rideId) {
    return _post('/ride-requests/$rideId/complete');
  }

  Future<Map<String, dynamic>> rateDriver({
    required int rideId,
    required double rating,
    String? comment,
  }) {
    return _post(
      '/ride-requests/$rideId/rate-driver',
      data: {
        'rating': rating,
        'comment': comment,
      },
    );
  }

  Future<Map<String, dynamic>> reportRide({
    required int rideId,
    required String reason,
    String? description,
  }) {
    return _post(
      '/ride-requests/$rideId/report',
      data: {
        'reason': reason,
        'description': description,
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRideList(String path) async {
    try {
      final response = await _apiClient.dio.get<List<dynamic>>(path);
      return response.data
              ?.whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          const [];
    } on DioException catch (error) {
      throw TrackingRemoteFailure(
          ApiErrorPayload.messageOrFallback(
        error,
        fallbackMessage: 'Impossible de charger les rides.',
      ));
    }
  }

  Future<Map<String, dynamic>> _fetchMap(String path) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(path);
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw TrackingRemoteFailure(_readError(error,
          fallback: 'Impossible de charger les donnees de tracking.'));
    }
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        path,
        data: data,
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw TrackingRemoteFailure(
          ApiErrorPayload.messageOrFallback(
        error,
        fallbackMessage: 'Action tracking impossible.',
      ));
    }
  }

  String _readError(DioException error, {required String fallback}) {
    return ApiErrorPayload.messageOrFallback(
      error,
      fallbackMessage: fallback,
    );
  }
}

final trackingRemoteDatasourceProvider =
    Provider<TrackingRemoteDatasource>((ref) {
  return TrackingRemoteDatasource(apiClient: ref.watch(apiClientProvider));
});
