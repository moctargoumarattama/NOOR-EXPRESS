import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_error.dart';
import 'models/driver_profile.dart';
import 'models/driver_stats.dart';

class DriverFailure implements Exception {
  const DriverFailure(this.message);

  final String message;
}

class DriverRepository {
  DriverRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<DriverProfile> fetchProfile() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/drivers/me/profile',
      );

      final payload = response.data;
      if (payload == null) {
        throw const DriverFailure('Profil driver introuvable.');
      }

      return DriverProfile.fromJson(payload);
    } on DioException catch (error) {
      throw DriverFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage: 'Impossible de charger le profil driver.',
        ),
      );
    }
  }

  Future<DriverProfile> updateAvailability(bool isAvailable) async {
    try {
      final response = await _apiClient.dio.put<Map<String, dynamic>>(
        '/drivers/me/availability',
        data: {'is_available': isAvailable},
      );

      final payload = response.data;
      if (payload == null) {
        throw const DriverFailure('Mise a jour de disponibilite impossible.');
      }

      return DriverProfile.fromJson(payload);
    } on DioException catch (error) {
      throw DriverFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage: 'Impossible de mettre a jour la disponibilite.',
        ),
      );
    }
  }

  Future<DriverProfile> updateProfile(DriverProfileUpdateInput input) async {
    try {
      final response = await _apiClient.dio.put<Map<String, dynamic>>(
        '/drivers/me/profile',
        data: input.toJson(),
      );

      final payload = response.data;
      if (payload == null) {
        throw const DriverFailure('Mise a jour du profil impossible.');
      }

      return DriverProfile.fromJson(payload);
    } on DioException catch (error) {
      throw DriverFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage: 'Impossible de mettre a jour le profil driver.',
        ),
      );
    }
  }

  Future<DriverStats> fetchStats() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/ride-requests/stats/driver/me',
      );

      final payload = response.data;
      if (payload == null) {
        throw const DriverFailure('Statistiques driver introuvables.');
      }

      return DriverStats.fromJson(payload);
    } on DioException catch (error) {
      throw DriverFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage: 'Impossible de charger les statistiques driver.',
        ),
      );
    }
  }
}

final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  return DriverRepository(apiClient: ref.watch(apiClientProvider));
});
