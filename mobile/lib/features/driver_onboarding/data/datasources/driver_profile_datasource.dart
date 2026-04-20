import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../models/driver_profile_model.dart';

class DriverProfileFailure implements Exception {
  const DriverProfileFailure(this.message);

  final String message;
}

class DriverProfileDatasource {
  DriverProfileDatasource({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<DriverOnboardingProfileModel?> fetchProfile() async {
    return _guard(() async {
      final response = await _apiClient.dio.get<dynamic>('/driver-profile/me');
      final payload = response.data;
      if (payload == null) {
        return null;
      }
      if (payload is Map<String, dynamic>) {
        return DriverOnboardingProfileModel.fromJson(payload);
      }
      throw const DriverProfileFailure('Dossier driver invalide.');
    });
  }

  Future<DriverOnboardingProfileModel> submitProfile(
    DriverProfileSubmitInput input,
  ) async {
    return _guard(() async {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/driver-profile/submit',
        data: input.toJson(),
      );
      final payload = response.data;
      if (payload == null) {
        throw const DriverProfileFailure('Soumission impossible.');
      }
      return DriverOnboardingProfileModel.fromJson(payload);
    });
  }

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DriverProfileFailure {
      rethrow;
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is String && detail.isNotEmpty) {
          throw DriverProfileFailure(detail);
        }
      }
      throw const DriverProfileFailure('Service verification indisponible.');
    }
  }
}

final driverProfileDatasourceProvider =
    Provider<DriverProfileDatasource>((ref) {
  return DriverProfileDatasource(apiClient: ref.watch(apiClientProvider));
});
