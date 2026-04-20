import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';

import '../config/app_config.dart';
import '../storage/secure_storage_service.dart';

class ApiClient {
  ApiClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 10),
            headers: const {
              'Content-Type': 'application/json',
            },
          ),
        ) {
    _dio.interceptors.add(DioCacheInterceptor(options: _cacheOptions));
    _dio.interceptors.add(
      RetryInterceptor(
        dio: _dio,
        retries: 2,
        retryDelays: const [
          Duration(milliseconds: 250),
          Duration(milliseconds: 700),
        ],
      ),
    );
    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_isCacheableGet(options)) {
            options.extra.addAll(
              _cacheOptions.copyWith(policy: CachePolicy.request).toExtra(),
            );
          }
          final hasAuthHeader = options.headers['Authorization'] != null;
          if (!hasAuthHeader && !_isAuthPath(options.path)) {
            final token = await _storageService.readToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (!_canAttemptRefresh(error)) {
            handler.next(error);
            return;
          }

          final refreshed = await _refreshAccessToken();
          if (refreshed == null) {
            await _handleAuthExpired();
            handler.next(error);
            return;
          }

          final retryOptions = error.requestOptions;
          retryOptions.headers['Authorization'] = 'Bearer $refreshed';
          retryOptions.extra['authRetry'] = true;

          try {
            final response = await _dio.fetch<dynamic>(retryOptions);
            handler.resolve(response);
          } on DioException catch (retryError) {
            handler.next(retryError);
          }
        },
      ),
    );
  }

  final Dio _dio;
  final SecureStorageService _storageService = const SecureStorageService();
  final CacheOptions _cacheOptions = CacheOptions(
    store: MemCacheStore(),
    policy: CachePolicy.noCache,
    maxStale: const Duration(minutes: 5),
    hitCacheOnErrorExcept: const [401, 403],
  );
  Future<void> Function()? _onAuthExpired;

  Dio get dio => _dio;

  String get baseUrl => _dio.options.baseUrl;

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  void setAuthExpiredHandler(Future<void> Function()? handler) {
    _onAuthExpired = handler;
  }

  bool _isAuthPath(String path) => path.startsWith('/auth/');

  bool _isCacheableGet(RequestOptions options) {
    if (options.method.toUpperCase() != 'GET') {
      return false;
    }

    return options.path == '/users/me' ||
        options.path == '/drivers/me/profile' ||
        options.path == '/pricing/zones';
  }

  bool _canAttemptRefresh(DioException error) {
    final statusCode = error.response?.statusCode;
    final alreadyRetried = error.requestOptions.extra['authRetry'] == true;
    return statusCode == 401 &&
        !alreadyRetried &&
        !_isAuthPath(error.requestOptions.path);
  }

  Future<String?> _refreshAccessToken() async {
    final refreshToken = await _storageService.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    try {
      final response = await Dio(
        BaseOptions(
          baseUrl: _dio.options.baseUrl,
          connectTimeout: _dio.options.connectTimeout,
          receiveTimeout: _dio.options.receiveTimeout,
          headers: const {'Content-Type': 'application/json'},
        ),
      ).post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final accessToken = response.data?['access_token'] as String?;
      if (accessToken == null || accessToken.isEmpty) {
        return null;
      }

      setAuthToken(accessToken);
      await _storageService.saveToken(accessToken);
      return accessToken;
    } on DioException {
      return null;
    }
  }

  Future<void> _handleAuthExpired() async {
    clearAuthToken();
    await _storageService.clearSession();
    await _onAuthExpired?.call();
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});
