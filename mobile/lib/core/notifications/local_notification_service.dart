import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isReady = false;

  Future<void> initialize() async {
    if (kIsWeb || _isReady) {
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    await _createAndroidChannels();
    _isReady = true;
  }

  Future<void> showRemoteMessage(RemoteMessage message) async {
    if (kIsWeb) {
      return;
    }

    await initialize();

    final notification = message.notification;
    final title = notification?.title ?? 'Noor Express';
    final body = notification?.body ?? '';
    final channelId = _channelIdForType(message.data['type']?.toString());

    await _plugin.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          _channelName(channelId),
          channelDescription: _channelDescription(channelId),
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFF1B8A5A),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> _createAndroidChannels() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) {
      return;
    }

    const channels = [
      AndroidNotificationChannel(
        'rides',
        'Courses',
        description: 'Notifications importantes liees aux courses.',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'offers',
        'Offres',
        description: 'Notifications importantes liees aux offres.',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'general',
        'General',
        description: 'Notifications generales Noor Express.',
      ),
    ];

    for (final channel in channels) {
      await androidPlugin.createNotificationChannel(channel);
    }
  }

  String _channelIdForType(String? type) {
    if (type == 'new_offer' ||
        type == 'offer_accepted' ||
        type == 'offer_rejected') {
      return 'offers';
    }
    if (type == 'new_ride_request' ||
        type == 'driver_en_route' ||
        type == 'driver_arrived' ||
        type == 'ride_started' ||
        type == 'ride_completed') {
      return 'rides';
    }
    return 'general';
  }

  String _channelName(String id) {
    return switch (id) {
      'rides' => 'Courses',
      'offers' => 'Offres',
      _ => 'General',
    };
  }

  String _channelDescription(String id) {
    return switch (id) {
      'rides' => 'Notifications temps reel des courses.',
      'offers' => 'Notifications temps reel des offres.',
      _ => 'Notifications Noor Express.',
    };
  }
}

final localNotificationServiceProvider =
    Provider<LocalNotificationService>((ref) {
  return LocalNotificationService();
});
