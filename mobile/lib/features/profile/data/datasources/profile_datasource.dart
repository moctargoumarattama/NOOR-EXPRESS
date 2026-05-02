import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/media/photo_picker_types.dart';
import '../../../../core/network/api_client.dart';
import '../models/client_profile_model.dart';

class ProfileFailure implements Exception {
  const ProfileFailure(this.message);

  final String message;
}

class ProfileDatasource {
  ProfileDatasource({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<ClientProfileModel> fetchClientProfile() async {
    try {
      final response =
          await _apiClient.dio.get<Map<String, dynamic>>('/users/me/profile');
      final payload = response.data;
      if (payload == null) {
        throw const ProfileFailure('Profil introuvable.');
      }
      return ClientProfileModel.fromJson(payload);
    } on DioException catch (error) {
      throw ProfileFailure(
          _readError(error, 'Impossible de charger le profil.'));
    }
  }

  Future<ClientProfileModel> updateClientProfile({
    String? firstName,
    NoorPickedPhoto? profilePhoto,
  }) async {
    try {
      final formData = FormData.fromMap({
        if (firstName != null) 'first_name': firstName,
        if (profilePhoto != null)
          'profile_photo': MultipartFile.fromBytes(
            profilePhoto.bytes,
            filename: profilePhoto.name ?? 'profile_photo.jpg',
          ),
      });
      await _apiClient.dio.patch<Map<String, dynamic>>(
        '/users/me',
        data: formData,
      );
      return await fetchClientProfile();
    } on DioException catch (error) {
      throw ProfileFailure(
        _readError(error, 'Mise a jour du profil impossible.'),
      );
    }
  }

  Future<List<ClientProfileRideModel>> fetchRecentRides() async {
    try {
      final response = await _apiClient.dio.get<List<dynamic>>(
        '/ride-requests/client/me',
        queryParameters: {'limit': 20},
      );
      return response.data
              ?.whereType<Map>()
              .map((item) => ClientProfileRideModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList() ??
          const [];
    } on DioException catch (error) {
      throw ProfileFailure(
        _readError(error, 'Impossible de charger l historique.'),
      );
    }
  }

  String _readError(DioException error, String fallback) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
    }
    return fallback;
  }
}

final profileDatasourceProvider = Provider<ProfileDatasource>((ref) {
  return ProfileDatasource(apiClient: ref.watch(apiClientProvider));
});
