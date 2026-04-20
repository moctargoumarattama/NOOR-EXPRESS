import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../models/app_role.dart';
import '../models/auth_session.dart';
import '../network/api_client.dart';
import '../notifications/fcm_service.dart';
import '../storage/secure_storage_service.dart';

enum SessionStatus {
  initial,
  loading,
  unauthenticated,
  authenticated,
}

class SessionState {
  const SessionState({
    required this.status,
    this.userId,
    this.token,
    this.role,
    this.phoneNumber,
    this.name,
    this.refreshToken,
    this.errorMessage,
  });

  const SessionState.initial() : this(status: SessionStatus.initial);

  final SessionStatus status;
  final int? userId;
  final String? token;
  final AppRole? role;
  final String? phoneNumber;
  final String? name;
  final String? refreshToken;
  final String? errorMessage;

  SessionState copyWith({
    SessionStatus? status,
    int? userId,
    String? token,
    AppRole? role,
    String? phoneNumber,
    String? name,
    String? refreshToken,
    String? errorMessage,
    bool clearUserId = false,
    bool clearToken = false,
    bool clearRole = false,
    bool clearPhoneNumber = false,
    bool clearName = false,
    bool clearRefreshToken = false,
    bool clearErrorMessage = false,
  }) {
    return SessionState(
      status: status ?? this.status,
      userId: clearUserId ? null : userId ?? this.userId,
      token: clearToken ? null : token ?? this.token,
      role: clearRole ? null : role ?? this.role,
      phoneNumber: clearPhoneNumber ? null : phoneNumber ?? this.phoneNumber,
      name: clearName ? null : name ?? this.name,
      refreshToken:
          clearRefreshToken ? null : refreshToken ?? this.refreshToken,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }

  bool get isBusy => status == SessionStatus.loading;
}

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return const SecureStorageService();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(apiClient: ref.watch(apiClientProvider));
});

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
  return SessionController(
    authRepository: ref.watch(authRepositoryProvider),
    apiClient: ref.watch(apiClientProvider),
    fcmService: ref.watch(fcmServiceProvider),
    storageService: ref.watch(secureStorageServiceProvider),
  );
});

class SessionController extends StateNotifier<SessionState> {
  SessionController({
    required AuthRepository authRepository,
    required ApiClient apiClient,
    required FcmService fcmService,
    required SecureStorageService storageService,
  })  : _authRepository = authRepository,
        _apiClient = apiClient,
        _fcmService = fcmService,
        _storageService = storageService,
        super(const SessionState.initial()) {
    _apiClient.setAuthExpiredHandler(forceLogout);
  }

  final AuthRepository _authRepository;
  final ApiClient _apiClient;
  final FcmService _fcmService;
  final SecureStorageService _storageService;

  Future<void> restoreSession() async {
    if (state.status == SessionStatus.loading) {
      return;
    }

    state = state.copyWith(
      status: SessionStatus.loading,
      clearErrorMessage: true,
    );

    final token = await _storageService.readToken();
    final refreshToken = await _storageService.readRefreshToken();
    if (token == null) {
      _apiClient.clearAuthToken();
      state = const SessionState(status: SessionStatus.unauthenticated);
      return;
    }

    try {
      final session = await _authRepository.getCurrentSession(
        token,
        refreshToken: refreshToken,
      );
      await setAuthenticatedSession(session);
    } on AuthFailure catch (_) {
      _apiClient.clearAuthToken();
      await _storageService.clearSession();
      state = const SessionState(status: SessionStatus.unauthenticated);
    }
  }

  Future<void> login({
    required String phoneNumber,
  }) async {
    state = state.copyWith(
      status: SessionStatus.loading,
      clearErrorMessage: true,
    );

    try {
      final session = await _authRepository.login(
        phoneNumber: phoneNumber,
      );

      await setAuthenticatedSession(session);
    } on AuthFailure catch (error) {
      _apiClient.clearAuthToken();
      state = SessionState(
        status: SessionStatus.unauthenticated,
        errorMessage: error.message,
      );
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    await forceLogout();
  }

  Future<void> forceLogout() async {
    _apiClient.clearAuthToken();
    await _storageService.clearSession();
    state = const SessionState(status: SessionStatus.unauthenticated);
  }

  Future<void> setAuthenticatedSession(AuthSession session) async {
    _apiClient.setAuthToken(session.token);
    await _persistSession(session);
    unawaited(_fcmService.registerCurrentToken());
    state = SessionState(
      status: SessionStatus.authenticated,
      userId: session.userId,
      token: session.token,
      role: session.role,
      phoneNumber: session.phoneNumber,
      name: session.name,
      refreshToken: session.refreshToken,
    );
  }

  Future<void> _persistSession(AuthSession session) async {
    await _storageService.saveSession(
      userId: session.userId,
      token: session.token,
      role: session.role,
      phoneNumber: session.phoneNumber,
      refreshToken: session.refreshToken,
    );
  }
}
