import 'package:dio/dio.dart';

import '../../../core/constants/app_messages.dart';
import '../../../core/models/app_role.dart';
import '../../../core/models/auth_session.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/api_client.dart';

enum AuthFailureType {
  unauthorized,
  offline,
  timeout,
  serverUnavailable,
  unknown,
}

class AuthFailure implements Exception {
  const AuthFailure(
    this.message, {
    this.type = AuthFailureType.unknown,
  });

  final String message;
  final AuthFailureType type;
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
      final refreshToken = loginResponse.data?['refresh_token'] as String?;
      if (accessToken == null || accessToken.isEmpty) {
        throw const AuthFailure(AppMessages.authTokenMissing);
      }

      return getCurrentSession(accessToken, refreshToken: refreshToken);
    } on DioException catch (error) {
      throw AuthFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage: AppMessages.authLoginUnavailable,
        ),
        type: _mapIssueType(ApiErrorPayload.classifyDio(error)),
      );
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
        throw const AuthFailure(AppMessages.authCurrentUserNotFound);
      }

      final userId = payload['id'] as int?;
      final role = AppRoleX.fromStorageValue(payload['role'] as String?);
      final phoneNumber = payload['phone_number'] as String?;

      if (userId == null ||
          role == null ||
          phoneNumber == null ||
          phoneNumber.isEmpty) {
        throw const AuthFailure(AppMessages.authUserProfileInvalid);
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
        name:
            (payload['first_name'] as String?) ?? (payload['name'] as String?),
        refreshToken: refreshToken,
      );
    } on DioException catch (error) {
      final message = _extractErrorMessage(error);
      if (message != null) {
        final statusCode = error.response?.statusCode;
        if (statusCode == 401 || statusCode == 403) {
          throw const AuthFailure(
            AppMessages.authSessionExpiredReconnect,
            type: AuthFailureType.unauthorized,
          );
        }
        throw AuthFailure(
          message,
          type: _mapIssueType(ApiErrorPayload.classifyDio(error)),
        );
      }

      final statusCode = error.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        throw const AuthFailure(
          AppMessages.authSessionExpiredReconnect,
          type: AuthFailureType.unauthorized,
        );
      }

      throw AuthFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage: AppMessages.authProfileLoadFailed,
        ),
        type: _mapIssueType(ApiErrorPayload.classifyDio(error)),
      );
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.dio.post<void>('/auth/logout');
    } on DioException {
      // Logout local reste prioritaire si le token est deja expire.
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _apiClient.dio.delete<void>('/users/me');
    } on DioException catch (error) {
      throw AuthFailure(
        ApiErrorPayload.messageOrFallback(
          error,
          fallbackMessage: AppMessages.authDeleteAccountFailed,
        ),
        type: _mapIssueType(ApiErrorPayload.classifyDio(error)),
      );
    }
  }

  String? _extractErrorMessage(DioException error) {
    final detail = error.response?.data;
    if (detail is! Map<String, dynamic>) {
      return null;
    }

    final payloadMessage = detail['message'];
    if (payloadMessage is String && payloadMessage.isNotEmpty) {
      return payloadMessage;
    }

    final errorDetail = detail['detail'];
    if (errorDetail is String && errorDetail.isNotEmpty) {
      return errorDetail;
    }
    return null;
  }

  AuthFailureType _mapIssueType(ApiIssueType issueType) {
    switch (issueType) {
      case ApiIssueType.offline:
        return AuthFailureType.offline;
      case ApiIssueType.timeout:
        return AuthFailureType.timeout;
      case ApiIssueType.serverUnavailable:
        return AuthFailureType.serverUnavailable;
      case ApiIssueType.unknown:
        return AuthFailureType.unknown;
    }
  }
}
