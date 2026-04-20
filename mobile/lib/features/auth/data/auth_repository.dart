import 'package:dio/dio.dart';

import '../../../core/models/app_role.dart';
import '../../../core/models/auth_session.dart';
import '../../../core/network/api_client.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;
}

class AuthRepository {
  AuthRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<AuthSession> login({
    required String phoneNumber,
  }) async {
    try {
      final loginResponse = await _apiClient.dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'phone_number': phoneNumber,
        },
      );

      final accessToken = loginResponse.data?['access_token'] as String?;
      if (accessToken == null || accessToken.isEmpty) {
        throw const AuthFailure('Token JWT introuvable.');
      }

      return getCurrentSession(accessToken);
    } on DioException catch (error) {
      final detail = error.response?.data;
      if (detail is Map<String, dynamic>) {
        final message = detail['detail'];
        if (message is String && message.isNotEmpty) {
          throw AuthFailure(message);
        }
      }

      throw const AuthFailure('Connexion impossible pour le moment.');
    }
  }

  Future<AuthSession> getCurrentSession(
    String token, {
    String? refreshToken,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/users/me',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final payload = response.data;
      if (payload == null) {
        throw const AuthFailure('Utilisateur courant introuvable.');
      }

      final userId = payload['id'] as int?;
      final role = AppRoleX.fromStorageValue(payload['role'] as String?);
      final phoneNumber = payload['phone_number'] as String?;

      if (userId == null ||
          role == null ||
          phoneNumber == null ||
          phoneNumber.isEmpty) {
        throw const AuthFailure('Profil utilisateur invalide.');
      }

      final authHeader = _apiClient.dio.options.headers['Authorization'];
      final activeToken =
          authHeader is String && authHeader.startsWith('Bearer ')
              ? authHeader.substring(7)
              : token;

      return AuthSession(
        userId: userId,
        token: activeToken,
        role: role,
        phoneNumber: phoneNumber,
        name: payload['name'] as String?,
        refreshToken: refreshToken,
      );
    } on DioException catch (error) {
      final detail = error.response?.data;
      if (detail is Map<String, dynamic>) {
        final message = detail['detail'];
        if (message is String && message.isNotEmpty) {
          throw AuthFailure(message);
        }
      }

      final statusCode = error.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        throw const AuthFailure('Session expiree, reconnecte-toi.');
      }

      throw const AuthFailure('Impossible de charger le profil utilisateur.');
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.dio.post<void>('/auth/logout');
    } on DioException {
      // Logout local reste prioritaire si le token est deja expire.
    }
  }
}
