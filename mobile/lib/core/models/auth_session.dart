import 'app_role.dart';

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.token,
    required this.role,
    required this.phoneNumber,
    this.name,
    this.refreshToken,
  });

  final int userId;
  final String token;
  final AppRole role;
  final String phoneNumber;
  final String? name;
  final String? refreshToken;
}
