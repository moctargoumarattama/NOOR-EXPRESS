import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_messages.dart';
import '../../../../core/models/app_role.dart';
import '../../../../core/models/auth_session.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/network/api_client.dart';
import '../models/auth_model.dart';

class AuthDataFailure implements Exception {
  const AuthDataFailure(this.message);

  final String message;
}

class AuthDatasource {
  AuthDatasource({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<AuthUserModel> register({
    required String phoneNumber,
    required String name,
    required AppRole role,
  }) async {
    return _guard(() async {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'phone_number': phoneNumber,
          'name': name,
          'role': role.storageValue,
        },
      );
      return AuthUserModel.fromJson(response.data ?? {});
    });
  }

  Future<void> sendOtp({required String phoneNumber}) async {
    await _guard(() async {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/auth/otp/send',
        data: {'phone_number': phoneNumber},
      );
    });
  }

  Future<AuthSession> verifyOtp({
    required String phoneNumber,
    required String code,
  }) async {
    return _guard(() async {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/auth/otp/verify',
        data: {
          'phone_number': phoneNumber,
          'code': code,
        },
      );
      final tokens = AuthTokenPair.fromJson(response.data ?? {});
      if (tokens.accessToken.isEmpty || tokens.refreshToken.isEmpty) {
        throw const AuthDataFailure(AppMessages.authDataTokenInvalid);
      }
      return getCurrentSession(
        tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
    });
  }

  Future<AuthSession> getCurrentSession(
    String accessToken, {
    String? refreshToken,
  }) async {
    return _guard(() async {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/users/me',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final user = AuthUserModel.fromJson(response.data ?? {});
      if (user.id == 0 || user.phoneNumber.isEmpty) {
        throw const AuthDataFailure(AppMessages.authUserProfileInvalid);
      }
      final authHeader = _apiClient.dio.options.headers['Authorization'];
      final activeToken =
          authHeader is String && authHeader.startsWith('Bearer ')
              ? authHeader.substring(7)
              : accessToken;
      return AuthSession(
        userId: user.id,
        token: activeToken,
        role: user.role,
        phoneNumber: user.phoneNumber,
        name: user.name,
        refreshToken: refreshToken,
      );
    });
  }

  Future<String> refreshToken({required String refreshToken}) async {
    return _guard(() async {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final accessToken = response.data?['access_token'] as String?;
      if (accessToken == null || accessToken.isEmpty) {
        throw const AuthDataFailure(AppMessages.authRefreshTokenInvalid);
      }
      return accessToken;
    });
  }

  Future<void> logout() async {
    await _guard(() async {
      await _apiClient.dio.post<void>('/auth/logout');
    });
  }

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on AuthDataFailure {
      rethrow;
    } on DioException catch (error) {
      final detail = error.response?.data;
      if (detail is Map<String, dynamic>) {
        final message = detail['detail'];
        if (message is String && message.isNotEmpty) {
          throw AuthDataFailure(message);
        }
      }
      throw AuthDataFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage: AppMessages.authServiceUnavailable,
        ),
      );
    }
  }
}

final authDatasourceProvider = Provider<AuthDatasource>((ref) {
  return AuthDatasource(apiClient: ref.watch(apiClientProvider));
});
