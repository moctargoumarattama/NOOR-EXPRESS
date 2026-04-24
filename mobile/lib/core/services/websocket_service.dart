import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'websocket_resilience.dart';

enum WebSocketStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class WebSocketService {
  WebSocketService({this.debugLabel = 'ws'});

  final String debugLabel;

  final _messagesController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<WebSocketStatus>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;
  Timer? _reconnectTimer;
  Timer? _watchdogTimer;
  String? _currentUrl;
  bool _manualDisconnect = false;
  bool _disposed = false;
  int _reconnectAttempt = 0;
  DateTime? _lastLocationUpdateAt;
  DateTime? _lastActivityAt;
  Map<String, dynamic>? _pendingLocationPayload;
  WebSocketStatus _status = WebSocketStatus.disconnected;

  Stream<Map<String, dynamic>> get messages => _messagesController.stream;
  Stream<WebSocketStatus> get statuses => _statusController.stream;
  WebSocketStatus get status => _status;

  Future<void> connect(String url) async {
    if (_disposed) {
      return;
    }

    _manualDisconnect = false;
    _currentUrl = url;

    if (_status == WebSocketStatus.connected ||
        _status == WebSocketStatus.connecting) {
      return;
    }

    _setStatus(
      _status == WebSocketStatus.disconnected
          ? WebSocketStatus.connecting
          : WebSocketStatus.reconnecting,
    );

    try {
      await _closeChannel();
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _channelSubscription = _channel!.stream.listen(
        _handleMessage,
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('[$debugLabel] websocket error: $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('[$debugLabel] websocket closed');
          _handleDisconnect();
        },
        cancelOnError: true,
      );
      _reconnectAttempt = 0;
      _recordActivity();
      _startWatchdog();
      _setStatus(WebSocketStatus.connected);
      _flushBufferedLocation();
      debugPrint('[$debugLabel] websocket connected');
    } catch (error) {
      debugPrint('[$debugLabel] websocket connect failed: $error');
      _handleDisconnect();
    }
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    await _closeChannel();
    _setStatus(WebSocketStatus.disconnected);
  }

  void sendJson(Map<String, dynamic> payload) {
    if (_isLocationPayload(payload)) {
      _pendingLocationPayload = Map<String, dynamic>.from(payload);
    }
    if (_status != WebSocketStatus.connected || _channel == null) {
      return;
    }
    try {
      _channel!.sink.add(jsonEncode(payload));
    } catch (error) {
      debugPrint('[$debugLabel] websocket send failed: $error');
      unawaited(_restartFromWatchdog());
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await disconnect();
    await _messagesController.close();
    await _statusController.close();
  }

  void _handleMessage(dynamic rawMessage) {
    if (_disposed || rawMessage == null) {
      return;
    }
    _recordActivity();

    try {
      final payload = jsonDecode(rawMessage as String);
      if (payload is Map<String, dynamic>) {
        if (_handleProtocolMessage(payload) ||
            _shouldThrottleLocation(payload)) {
          return;
        }
        _messagesController.add(payload);
      } else if (payload is Map) {
        final normalizedPayload = Map<String, dynamic>.from(payload);
        if (_handleProtocolMessage(normalizedPayload) ||
            _shouldThrottleLocation(normalizedPayload)) {
          return;
        }
        _messagesController.add(normalizedPayload);
      }
    } catch (error) {
      debugPrint('[$debugLabel] invalid websocket message: $error');
    }
  }

  void _handleDisconnect([Object? error]) {
    if (_disposed) {
      return;
    }

    if (error != null) {
      debugPrint('[$debugLabel] websocket disconnected: $error');
    }

    _stopWatchdog();
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel = null;

    if (_manualDisconnect) {
      _setStatus(WebSocketStatus.disconnected);
      return;
    }

    _setStatus(WebSocketStatus.reconnecting);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final url = _currentUrl;
    if (url == null) {
      return;
    }

    final delay = websocketReconnectDelay(attempt: _reconnectAttempt);
    _reconnectAttempt += 1;
    _reconnectTimer = Timer(delay, () {
      connect(url);
    });
  }

  bool _handleProtocolMessage(Map<String, dynamic> payload) {
    if (payload['type'] != 'ping') {
      return false;
    }
    sendJson({'type': 'pong'});
    return true;
  }

  bool _shouldThrottleLocation(Map<String, dynamic> payload) {
    final type = payload['type'];
    if (type != 'driver_position_update' && type != 'location_update') {
      return false;
    }

    final now = DateTime.now();
    final lastUpdate = _lastLocationUpdateAt;
    if (lastUpdate != null &&
        now.difference(lastUpdate) < const Duration(milliseconds: 100)) {
      return true;
    }
    _lastLocationUpdateAt = now;
    return false;
  }

  Future<void> _closeChannel() async {
    _reconnectTimer?.cancel();
    _stopWatchdog();
    await _channelSubscription?.cancel();
    _channelSubscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void _setStatus(WebSocketStatus nextStatus) {
    _status = nextStatus;
    if (!_statusController.isClosed) {
      _statusController.add(nextStatus);
    }
  }

  bool _isLocationPayload(Map<String, dynamic> payload) {
    return payload['type'] == 'location_update';
  }

  void _recordActivity() {
    _lastActivityAt = DateTime.now();
  }

  void _flushBufferedLocation() {
    final payload = _pendingLocationPayload;
    if (payload == null || _status != WebSocketStatus.connected) {
      return;
    }
    sendJson(payload);
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(websocketWatchdogInterval, (_) {
      if (_status != WebSocketStatus.connected || _manualDisconnect) {
        return;
      }
      if (!isWebSocketConnectionStale(
        now: DateTime.now(),
        lastActivityAt: _lastActivityAt,
      )) {
        return;
      }
      debugPrint('[$debugLabel] websocket stale, forcing reconnect');
      unawaited(_restartFromWatchdog());
    });
  }

  void _stopWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

  Future<void> _restartFromWatchdog() async {
    if (_disposed || _manualDisconnect || _currentUrl == null) {
      return;
    }
    await _closeChannel();
    _setStatus(WebSocketStatus.reconnecting);
    _scheduleReconnect();
  }
}

String buildWebSocketUrl(
  String baseUrl,
  String path, {
  Map<String, String>? queryParameters,
}) {
  final uri = Uri.parse(baseUrl);
  final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
  final normalizedPath = path.startsWith('/') ? path : '/$path';
  return uri
      .replace(
        scheme: scheme,
        path: normalizedPath,
        queryParameters: queryParameters,
      )
      .toString();
}

final websocketProvider =
    Provider.autoDispose.family<WebSocketService, String>((ref, scope) {
  final service = WebSocketService(debugLabel: scope);
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});
