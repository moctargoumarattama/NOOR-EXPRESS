import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_role.dart';
import '../../../../core/state/session_controller.dart';
import '../../data/datasources/auth_datasource.dart';
import '../../domain/entities/auth_state.dart';

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    datasource: ref.watch(authDatasourceProvider),
    ref: ref,
  );
});

class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required AuthDatasource datasource,
    required Ref ref,
  })  : _datasource = datasource,
        _ref = ref,
        super(const AuthState.initial());

  final AuthDatasource _datasource;
  final Ref _ref;

  void selectRole(AppRole role) {
    state = state.copyWith(role: role, clearErrorMessage: true);
  }

  Future<bool> registerAndSendOtp({
    required String name,
    required String phoneNumber,
  }) async {
    final normalizedPhone = _normalizeNigerPhone(phoneNumber);
    if (name.trim().isEmpty || normalizedPhone.length < 12) {
      state = state.copyWith(
        errorMessage: 'Renseigne un nom et un numero valide.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      await _datasource.register(
        phoneNumber: normalizedPhone,
        name: name.trim(),
        role: state.role,
      );
      await _datasource.sendOtp(phoneNumber: normalizedPhone);
      state = state.copyWith(
        isLoading: false,
        name: name.trim(),
        phoneNumber: normalizedPhone,
        clearErrorMessage: true,
      );
      return true;
    } on AuthDataFailure catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.message,
      );
      return false;
    }
  }

  Future<bool> resendOtp() async {
    final phoneNumber = state.phoneNumber;
    if (phoneNumber == null || phoneNumber.isEmpty) {
      state = state.copyWith(errorMessage: 'Numero introuvable.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      await _datasource.sendOtp(phoneNumber: phoneNumber);
      state = state.copyWith(isLoading: false, clearErrorMessage: true);
      return true;
    } on AuthDataFailure catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
      return false;
    }
  }

  Future<AppRole?> verifyOtp(String code) async {
    final phoneNumber = state.phoneNumber;
    if (phoneNumber == null || phoneNumber.isEmpty || code.length != 4) {
      state = state.copyWith(errorMessage: 'Code OTP invalide.');
      return null;
    }

    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final session = await _datasource.verifyOtp(
        phoneNumber: phoneNumber,
        code: code,
      );
      await _ref
          .read(sessionControllerProvider.notifier)
          .setAuthenticatedSession(session);
      state = state.copyWith(isLoading: false, clearErrorMessage: true);
      return session.role;
    } on AuthDataFailure catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
      return null;
    }
  }

  String _normalizeNigerPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('227')) {
      return '+$digits';
    }
    return '+227$digits';
  }
}
