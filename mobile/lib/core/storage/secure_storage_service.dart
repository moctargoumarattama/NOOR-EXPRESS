import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/app_role.dart';

class SecureStorageService {
  const SecureStorageService();

  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _userIdKey = 'auth_user_id';
  static const _roleKey = 'auth_role';
  static const _phoneNumberKey = 'auth_phone_number';

  FlutterSecureStorage get _storage => const FlutterSecureStorage();

  Future<void> saveSession({
    required int userId,
    required String token,
    required AppRole role,
    required String phoneNumber,
    String? refreshToken,
  }) async {
    await _storage.write(key: _userIdKey, value: userId.toString());
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _roleKey, value: role.storageValue);
    await _storage.write(key: _phoneNumberKey, value: phoneNumber);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> saveToken(String token) => _storage.write(
        key: _tokenKey,
        value: token,
      );

  Future<void> saveRefreshToken(String refreshToken) => _storage.write(
        key: _refreshTokenKey,
        value: refreshToken,
      );

  Future<int?> readUserId() async {
    final storedValue = await _storage.read(key: _userIdKey);
    return int.tryParse(storedValue ?? '');
  }

  Future<AppRole?> readRole() async {
    final storedRole = await _storage.read(key: _roleKey);
    return AppRoleX.fromStorageValue(storedRole);
  }

  Future<String?> readPhoneNumber() => _storage.read(key: _phoneNumberKey);

  Future<void> clearSession() => _storage.deleteAll();
}
