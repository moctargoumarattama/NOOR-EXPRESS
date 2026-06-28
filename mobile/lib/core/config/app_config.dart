import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const _productionApiBaseUrl = 'https://forlife.pythonanywhere.com';
  static const _apiBaseUrlOverride = String.fromEnvironment(
    'NOOR_API_BASE_URL',
  );
  static const _wsBaseUrlOverride = String.fromEnvironment(
    'NOOR_WS_BASE_URL',
  );
  static const _webHost = 'localhost:3000';
  static const _backendPort = 8000;

  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.trim().isNotEmpty) {
      return _withoutTrailingSlash(_apiBaseUrlOverride);
    }

    if (kIsWeb) {
      return _isLocalWebHost(Uri.base.host)
          ? 'http://localhost:$_backendPort'
          : _productionApiBaseUrl;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:$_backendPort';
      default:
        return 'http://localhost:$_backendPort';
    }
  }

  static String get wsBaseUrl {
    if (_wsBaseUrlOverride.trim().isNotEmpty) {
      return _withoutTrailingSlash(_wsBaseUrlOverride);
    }

    if (kIsWeb && !_isLocalWebHost(Uri.base.host)) {
      return 'wss://forlife.pythonanywhere.com';
    }

    final uri = Uri.parse(apiBaseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return _withoutTrailingSlash(
        uri.replace(scheme: scheme, path: '').toString());
  }

  static String buildWsUrl(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse(wsBaseUrl).replace(path: normalizedPath).toString();
  }

  static String get webDemoUrl => 'http://$_webHost';

  static String _withoutTrailingSlash(String value) {
    return value.replaceAll(RegExp(r'/$'), '');
  }

  static bool _isLocalWebHost(String host) {
    final normalized = host.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1';
  }
}

abstract final class AppConstants {
  static const supportPhone = '+22790000000';
  static const supportHours = 'Tous les jours 06:00-23:00';
}
