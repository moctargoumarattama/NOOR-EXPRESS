import '../../../../core/models/app_role.dart';

class AuthState {
  const AuthState({
    required this.isLoading,
    this.name,
    this.phoneNumber,
    this.role = AppRole.client,
    this.errorMessage,
  });

  const AuthState.initial() : this(isLoading: false);

  final bool isLoading;
  final String? name;
  final String? phoneNumber;
  final AppRole role;
  final String? errorMessage;

  AuthState copyWith({
    bool? isLoading,
    String? name,
    String? phoneNumber,
    AppRole? role,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}
