import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/firebase_options.dart';
import 'core/map/tile_cache_service.dart';
import 'core/network/api_client.dart';
import 'core/notifications/fcm_service.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/notifications/notification_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initialiseTileCache();
  await _initialiseFirebaseNotifications();
  runApp(const ProviderScope(child: NoorExpressApp()));
}

Future<void> _initialiseTileCache() => initialiseTileCache();

Future<void> _initialiseFirebaseNotifications() async {
  if (!DefaultFirebaseOptions.isConfigured) {
    return;
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await FcmService(
    apiClient: ApiClient(),
    localNotificationService: LocalNotificationService(),
    notificationHandler: NotificationHandler(),
  ).initialize();
}
