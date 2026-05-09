import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_event.dart';

class NotificationInboxEntry {
  const NotificationInboxEntry({
    required this.id,
    required this.title,
    required this.message,
    required this.receivedAt,
    this.type,
    this.externalId,
    this.data = const <String, dynamic>{},
    this.source = 'fcm',
  });

  final String id;
  final String title;
  final String message;
  final String? type;
  final String? externalId;
  final DateTime receivedAt;
  final Map<String, dynamic> data;
  final String source;

  factory NotificationInboxEntry.fromJson(Map<String, dynamic> json) {
    final dateText = json['received_at'] as String?;
    final receivedAt = DateTime.tryParse(dateText ?? '') ?? DateTime.now();
    final rawData = json['data'];
    return NotificationInboxEntry(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Noor Express',
      message: json['message'] as String? ?? '',
      type: json['type'] as String?,
      externalId: json['external_id'] as String?,
      receivedAt: receivedAt,
      data: rawData is Map<String, dynamic>
          ? rawData
          : const <String, dynamic>{},
      source: json['source'] as String? ?? 'fcm',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'external_id': externalId,
      'received_at': receivedAt.toIso8601String(),
      'data': data,
      'source': source,
    };
  }
}

class NotificationInboxService {
  NotificationInboxService({SharedPreferences? preferences})
      : _preferences = preferences;

  static const int maxEntries = 30;
  static const String _storageKey = 'notification_inbox.v1';

  final SharedPreferences? _preferences;

  Future<List<NotificationInboxEntry>> fetchRecent({
    int limit = maxEntries,
  }) async {
    final all = await _readEntries();
    if (all.length <= limit) {
      return all;
    }
    return all.sublist(0, limit);
  }

  Future<void> clear() async {
    final prefs = await _resolvePreferences();
    await prefs.remove(_storageKey);
  }

  Future<void> addRemoteMessage(
    RemoteMessage message, {
    String source = 'fcm_foreground',
  }) async {
    final data = Map<String, dynamic>.from(message.data);
    await addPayload(
      data: data,
      title: message.notification?.title,
      body: message.notification?.body,
      externalId: message.messageId,
      receivedAt: message.sentTime ?? DateTime.now(),
      source: source,
    );
  }

  Future<void> addPayload({
    required Map<String, dynamic> data,
    String? title,
    String? body,
    String? externalId,
    DateTime? receivedAt,
    String source = 'fcm_payload',
  }) async {
    final entries = await _readEntries();
    final normalizedExternalId = externalId?.trim();
    if (normalizedExternalId != null &&
        normalizedExternalId.isNotEmpty &&
        entries.any((entry) => entry.externalId == normalizedExternalId)) {
      return;
    }

    final resolvedTitle = _resolveTitle(data, title);
    final resolvedMessage = notificationInAppMessageForPayload(
      data,
      title: resolvedTitle,
      body: body,
    );
    final now = receivedAt ?? DateTime.now();

    final entry = NotificationInboxEntry(
      id: '${now.microsecondsSinceEpoch}-${data['type'] ?? 'general'}',
      title: resolvedTitle,
      message: resolvedMessage,
      type: data['type']?.toString(),
      externalId: normalizedExternalId,
      receivedAt: now,
      data: Map<String, dynamic>.from(data),
      source: source,
    );

    final next = <NotificationInboxEntry>[entry, ...entries];
    next.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    final trimmed = next.take(maxEntries).toList(growable: false);
    await _writeEntries(trimmed);
  }

  Future<List<NotificationInboxEntry>> _readEntries() async {
    final prefs = await _resolvePreferences();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <NotificationInboxEntry>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <NotificationInboxEntry>[];
      }
      final entries = <NotificationInboxEntry>[];
      for (final item in decoded) {
        if (item is Map) {
          entries.add(
            NotificationInboxEntry.fromJson(
              item.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            ),
          );
        }
      }
      return entries;
    } catch (_) {
      return const <NotificationInboxEntry>[];
    }
  }

  Future<void> _writeEntries(List<NotificationInboxEntry> entries) async {
    final prefs = await _resolvePreferences();
    final payload = entries.map((entry) => entry.toJson()).toList(growable: false);
    await prefs.setString(_storageKey, jsonEncode(payload));
  }

  Future<SharedPreferences> _resolvePreferences() async {
    final prefs = _preferences;
    if (prefs != null) {
      return prefs;
    }
    return SharedPreferences.getInstance();
  }

  String _resolveTitle(Map<String, dynamic> data, String? title) {
    final titleValue = title?.trim();
    if (titleValue != null && titleValue.isNotEmpty) {
      return titleValue;
    }
    final dataTitle = data['title']?.toString().trim();
    if (dataTitle != null && dataTitle.isNotEmpty) {
      return dataTitle;
    }
    return 'Noor Express';
  }
}

Future<void> persistBackgroundRemoteMessage(RemoteMessage message) async {
  try {
    final service = NotificationInboxService();
    await service.addRemoteMessage(message, source: 'fcm_background');
  } catch (error) {
    debugPrint('[FCM] Historique background ignore: $error');
  }
}

final notificationInboxServiceProvider = Provider<NotificationInboxService>(
  (ref) => NotificationInboxService(),
);
