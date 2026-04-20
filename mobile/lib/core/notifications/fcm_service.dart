import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import 'local_notification_service.dart';
import 'notification_handler.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Message background recu: ${message.messageId}');
}

class FcmService {
  FcmService({
    required ApiClient apiClient,
    required LocalNotificationService localNotificationService,
    required NotificationHandler notificationHandler,
  })  : _apiClient = apiClient,
        _localNotificationService = localNotificationService,
        _notificationHandler = notificationHandler;

  final ApiClient _apiClient;
  final LocalNotificationService _localNotificationService;
  final NotificationHandler _notificationHandler;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized || Firebase.apps.isEmpty) {
      return;
    }

    try {
      await _localNotificationService.initialize();
      await _requestPermission();
      await registerCurrentToken();

      FirebaseMessaging.instance.onTokenRefresh.listen(_sendToken);
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleOpenedMessage(initialMessage);
      }

      _isInitialized = true;
    } catch (error) {
      debugPrint('[FCM] Initialisation ignoree: $error');
    }
  }

  Future<void> registerCurrentToken() async {
    if (Firebase.apps.isEmpty) {
      return;
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _sendToken(token);
      }
    } catch (error) {
      debugPrint('[FCM] Token indisponible: $error');
    }
  }

  Future<void> _requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus.name}');
  }

  Future<void> _sendToken(String token) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/notifications/token',
        data: {'fcm_token': token},
      );
    } on DioException catch (error) {
      debugPrint('[FCM] Enregistrement token impossible: ${error.message}');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await _localNotificationService.showRemoteMessage(message);
  }

  void _handleOpenedMessage(RemoteMessage message) {
    _notificationHandler.handleTap(message.data);
  }
}

final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService(
    apiClient: ref.watch(apiClientProvider),
    localNotificationService: ref.watch(localNotificationServiceProvider),
    notificationHandler: ref.watch(notificationHandlerProvider),
  );
});
