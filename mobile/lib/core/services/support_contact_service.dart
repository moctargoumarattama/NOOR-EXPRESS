import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../models/app_role.dart';
import '../network/api_client.dart';

enum SupportContactResultType {
  openedWhatsApp,
  openedWebFallback,
  failed,
}

class SupportContactResult {
  const SupportContactResult._(this.type);

  final SupportContactResultType type;

  const SupportContactResult.openedWhatsApp()
      : this._(SupportContactResultType.openedWhatsApp);

  const SupportContactResult.openedWebFallback()
      : this._(SupportContactResultType.openedWebFallback);

  const SupportContactResult.failed() : this._(SupportContactResultType.failed);
}

abstract interface class SupportContactUrlLauncher {
  Future<bool> canLaunch(Uri uri);

  Future<bool> launch(Uri uri);
}

class UrlLauncherSupportContactUrlLauncher
    implements SupportContactUrlLauncher {
  const UrlLauncherSupportContactUrlLauncher();

  @override
  Future<bool> canLaunch(Uri uri) {
    return canLaunchUrl(uri);
  }

  @override
  Future<bool> launch(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

abstract interface class SupportContactStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

class SharedPreferencesSupportContactStore implements SupportContactStore {
  const SharedPreferencesSupportContactStore();

  @override
  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<void> write(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}

class SupportContactService {
  SupportContactService({
    ApiClient? apiClient,
    SupportContactUrlLauncher? launcher,
    SupportContactStore? store,
  })  : _apiClient = apiClient,
        _launcher = launcher ?? const UrlLauncherSupportContactUrlLauncher(),
        _store = store ?? const SharedPreferencesSupportContactStore();

  static const passengerSupportMessage =
      "Bonjour Noor Express, j'ai besoin d'aide en tant que passager.";
  static const driverSupportMessage =
      "Bonjour Noor Express, j'ai besoin d'aide en tant que chauffeur.";
  static const _supportPhoneCacheKey = 'support_contact.whatsapp_phone';
  static const _supportHoursCacheKey = 'support_contact.hours';
  static const _termsPath = '/legal/terms';
  static const _privacyPath = '/legal/privacy';

  final ApiClient? _apiClient;
  final SupportContactUrlLauncher _launcher;
  final SupportContactStore _store;

  String _supportPhone = AppConstants.supportPhone;
  String _supportHours = AppConstants.supportHours;
  bool _cacheLoaded = false;

  String get supportPhone => _supportPhone;
  String get supportHours => _supportHours;

  Future<void> warmupConfig() async {
    await _loadCachedConfigIfNeeded();
    await refreshConfig();
  }

  Future<void> refreshConfig() async {
    final apiClient = _apiClient;
    if (apiClient == null) {
      return;
    }
    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        '/config/support',
      );
      final payload = response.data;
      if (payload == null) {
        return;
      }

      final phone = _sanitizeConfigValue(payload['whatsapp_number']);
      final hours = _sanitizeConfigValue(payload['support_hours']);

      if (phone != null && phone.isNotEmpty) {
        _supportPhone = phone;
        await _store.write(_supportPhoneCacheKey, phone);
      }
      if (hours != null && hours.isNotEmpty) {
        _supportHours = hours;
        await _store.write(_supportHoursCacheKey, hours);
      }
    } on DioException {
      // Ignore API failure and keep cached/default values.
    }
  }

  Future<SupportContactResult> openSupportChat(AppRole role) async {
    await _loadCachedConfigIfNeeded();
    final phone = _normalizePhoneNumber(_supportPhone);
    if (phone.isEmpty) {
      return const SupportContactResult.failed();
    }

    final message = _messageForRole(role);
    final whatsappUri = _whatsAppUri(phone, message);
    final canLaunchWhatsApp = await _safeCanLaunch(whatsappUri);
    if (canLaunchWhatsApp && await _safeLaunch(whatsappUri)) {
      return const SupportContactResult.openedWhatsApp();
    }

    final webUri = _waMeUri(phone, message);
    if (await _safeLaunch(webUri)) {
      return const SupportContactResult.openedWebFallback();
    }
    return const SupportContactResult.failed();
  }

  Future<bool> openTermsPage() {
    return _safeLaunch(_legalUri(_termsPath));
  }

  Future<bool> openPrivacyPage() {
    return _safeLaunch(_legalUri(_privacyPath));
  }

  Future<void> _loadCachedConfigIfNeeded() async {
    if (_cacheLoaded) {
      return;
    }
    _cacheLoaded = true;

    final cachedPhone = await _store.read(_supportPhoneCacheKey);
    final cachedHours = await _store.read(_supportHoursCacheKey);
    if (cachedPhone != null && cachedPhone.trim().isNotEmpty) {
      _supportPhone = cachedPhone.trim();
    }
    if (cachedHours != null && cachedHours.trim().isNotEmpty) {
      _supportHours = cachedHours.trim();
    }
  }

  String _messageForRole(AppRole role) {
    return role == AppRole.driver
        ? driverSupportMessage
        : passengerSupportMessage;
  }

  String? _sanitizeConfigValue(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  String _normalizePhoneNumber(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Uri _whatsAppUri(String phone, String message) {
    return Uri.parse(
      'whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}',
    );
  }

  Uri _waMeUri(String phone, String message) {
    return Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );
  }

  Uri _legalUri(String path) {
    final baseUrl = (_apiClient?.baseUrl ?? AppConfig.apiBaseUrl)
        .replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$baseUrl$path');
  }

  Future<bool> _safeCanLaunch(Uri uri) async {
    try {
      return await _launcher.canLaunch(uri);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _safeLaunch(Uri uri) async {
    try {
      return await _launcher.launch(uri);
    } catch (_) {
      return false;
    }
  }
}

final supportContactServiceProvider = Provider<SupportContactService>((ref) {
  return SupportContactService(
    apiClient: ref.watch(apiClientProvider),
  );
});
