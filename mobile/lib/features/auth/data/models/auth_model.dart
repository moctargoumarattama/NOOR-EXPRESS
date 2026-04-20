import '../../../../core/models/app_role.dart';

class AuthTokenPair {
  const AuthTokenPair({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;

  factory AuthTokenPair.fromJson(Map<String, dynamic> json) {
    return AuthTokenPair(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
    );
  }
}

class AuthUserModel {
  const AuthUserModel({
    required this.id,
    required this.phoneNumber,
    required this.role,
    this.name,
  });

  final int id;
  final String phoneNumber;
  final AppRole role;
  final String? name;

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    return AuthUserModel(
      id: json['id'] as int? ?? 0,
      phoneNumber: json['phone_number'] as String? ?? '',
      role:
          AppRoleX.fromStorageValue(json['role'] as String?) ?? AppRole.client,
      name: json['name'] as String?,
    );
  }
}
