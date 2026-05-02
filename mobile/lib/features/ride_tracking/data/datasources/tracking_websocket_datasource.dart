import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/services/websocket_resilience.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/entities/tracking_state.dart';
import '../models/ride_tracking_model.dart';

enum TrackingSocketEventType {
  rideStatus,
  driverLocation,
  rideMessage,
}

class TrackingSocketEvent {
  const TrackingSocketEvent.rideStatus({
    required this.rideId,
    required this.status,
  })  : type = TrackingSocketEventType.rideStatus,
        driverId = null,
        position = null,
        message = null;

  const TrackingSocketEvent.driverLocation({
    required this.driverId,
    required this.position,
  })  : type = TrackingSocketEventType.driverLocation,
        rideId = null,
        status = null,
        message = null;

  const TrackingSocketEvent.rideMessage({
    required this.rideId,
    required this.message,
  })  : type = TrackingSocketEventType.rideMessage,
        status = null,
        driverId = null,
        position = null;

  final TrackingSocketEventType type;
  final int? rideId;
  final String? status;
  final int? driverId;
  final TrackingCoordinates? position;
  final RideChatMessageModel? message;
}

class TrackingWebSocketDatasource {
  TrackingWebSocketDatasource({
    required this.debugLabel,
    required SecureStorageService storageService,
  }) : _storageService = storageService;

  final String debugLabel;
  final SecureStorageService _storageService;

  final _eventsController = StreamController<TrackingSocketEvent>.broadcast();
  final _connectionController =
      StreamController<TrackingConnectionState>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Timer? _watchdogTimer;
  String? _currentPath;
  bool _manualDisconnect = false;
  bool _disposed = false;
  int _reconnectAttempt = 0;
  DateTime? _lastActivityAt;
  Map<String, dynamic>? _pendingLocationPayload;
  TrackingConnectionState _connectionState =
      TrackingConnectionState.disconnected;

  Stream<TrackingSocketEvent> get events => _eventsController.stream;
  Stream<TrackingConnectionState> get connectionStates =>
      _connectionController.stream;

  Future<void> connectForClient(int clientId) {
    return _connect('/ws/clients/$clientId');
  }

  Future<void> connectForDriver(int driverId) {
    return _connect('/ws/drivers/$driverId');
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    await _closeChannel();
    _emitConnection(TrackingConnectionState.disconnected);
  }

  Future<void> resumeFromLifecycle() async {
    final path = _currentPath;
    if (_disposed || path == null) {
      return;
    }

    await disconnect();
    await _connect(path);
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await disconnect();
    await _eventsController.close();
    await _connectionController.close();
  }

  void sendLocationUpdate(TrackingCoordinates point) {
    final payload = {
      'type': 'location_update',
      'lat': point.latitude,
      'lng': point.longitude,
      'latitude': point.latitude,
      'longitude': point.longitude,
    };

    _pendingLocationPayload = payload;
    if (_connectionState != TrackingConnectionState.connected ||
        _channel == null) {
      return;
    }
    try {
      _channel!.sink.add(jsonEncode(payload));
    } catch (error) {
      debugPrint('[$debugLabel] sendLocationUpdate failed: $error');
      unawaited(_restartFromWatchdog());
    }
  }

  Future<void> _connect(String path) async {
    if (_disposed) {
      return;
    }

    _manualDisconnect = false;
    _currentPath = path;
    _emitConnection(
      _reconnectAttempt == 0
          ? TrackingConnectionState.connecting
          : TrackingConnectionState.reconnecting,
    );

    try {
      final token = await _storageService.readToken();
      final uri = Uri.parse(AppConfig.buildWsUrl(path));
      final authenticatedUri = uri.replace(
        queryParameters: token == null ? null : {'token': token},
      );
      await _closeChannel();
      _channel = WebSocketChannel.connect(authenticatedUri);
      _subscription = _channel!.stream.listen(
        _handleRawMessage,
        onError: _handleDisconnect,
        onDone: _handleDisconnect,
        cancelOnError: true,
      );
      _reconnectAttempt = 0;
      _recordActivity();
      _startWatchdog();
      _emitConnection(TrackingConnectionState.connected);
      _flushBufferedLocation();
    } catch (error) {
      debugPrint('[$debugLabel] websocket connect failed: $error');
      _handleDisconnect(error);
    }
  }

  void _handleRawMessage(dynamic raw) {
    if (_disposed || raw is! String) {
      return;
    }
    _recordActivity();

    try {
      final payload = jsonDecode(raw);
      if (payload is! Map) {
        return;
      }

      final message = Map<String, dynamic>.from(payload);
      if (message['type'] == 'ping') {
        _sendProtocolPayload({'type': 'pong'});
        return;
      }
      if (message['status'] == 'ok') {
        return;
      }

      final rideId = message['ride_request_id'] as int?;
      final status = message['status'] as String?;
      if (rideId != null && status != null) {
        _eventsController.add(
          TrackingSocketEvent.rideStatus(rideId: rideId, status: status),
        );
        return;
      }

      if (message['type'] == 'ride_message') {
        final messageJson = message['message'];
        if (rideId == null || messageJson is! Map) {
          return;
        }
        _eventsController.add(
          TrackingSocketEvent.rideMessage(
            rideId: rideId,
            message: RideChatMessageModel.fromJson(
              Map<String, dynamic>.from(messageJson),
            ),
          ),
        );
        return;
      }

      final type = message['type'] as String?;
      if (type == 'driver_position_update' || type == 'location_update') {
        final latitude = (message['latitude'] ?? message['lat']) as num?;
        final longitude = (message['longitude'] ?? message['lng']) as num?;
        if (latitude == null || longitude == null) {
          return;
        }

        _eventsController.add(
          TrackingSocketEvent.driverLocation(
            driverId: message['driver_id'] as int?,
            position: TrackingCoordinates(
              latitude: latitude.toDouble(),
              longitude: longitude.toDouble(),
            ),
          ),
        );
      }
    } catch (error) {
      debugPrint('[$debugLabel] invalid websocket payload: $error');
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
    _subscription?.cancel();
    _subscription = null;
    _channel = null;

    if (_manualDisconnect) {
      _emitConnection(TrackingConnectionState.disconnected);
      return;
    }

    _emitConnection(TrackingConnectionState.reconnecting);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    final path = _currentPath;
    if (path == null) {
      return;
    }

    _reconnectTimer?.cancel();
    final delay = websocketReconnectDelay(attempt: _reconnectAttempt);
    _reconnectAttempt += 1;
    _reconnectTimer = Timer(delay, () {
      _connect(path);
    });
  }

  Future<void> _closeChannel() async {
    _reconnectTimer?.cancel();
    _stopWatchdog();
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void _emitConnection(TrackingConnectionState state) {
    _connectionState = state;
    if (!_connectionController.isClosed) {
      _connectionController.add(state);
    }
  }

  void _recordActivity() {
    _lastActivityAt = DateTime.now();
  }

  void _flushBufferedLocation() {
    final payload = _pendingLocationPayload;
    if (payload == null) {
      return;
    }
    final latitude = (payload['latitude'] ?? payload['lat']) as num?;
    final longitude = (payload['longitude'] ?? payload['lng']) as num?;
    if (latitude == null || longitude == null) {
      return;
    }
    sendLocationUpdate(
      TrackingCoordinates(
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
      ),
    );
  }

  void _sendProtocolPayload(Map<String, dynamic> payload) {
    if (_connectionState != TrackingConnectionState.connected ||
        _channel == null) {
      return;
    }
    try {
      _channel!.sink.add(jsonEncode(payload));
    } catch (error) {
      debugPrint('[$debugLabel] protocol send failed: $error');
    }
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(websocketWatchdogInterval, (_) {
      if (_connectionState != TrackingConnectionState.connected ||
          _manualDisconnect) {
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
    if (_disposed || _manualDisconnect || _currentPath == null) {
      return;
    }
    await _closeChannel();
    _emitConnection(TrackingConnectionState.reconnecting);
    _scheduleReconnect();
  }
}

final trackingWebsocketDatasourceProvider =
    Provider.family<TrackingWebSocketDatasource, TrackingMode>((ref, mode) {
  final datasource = TrackingWebSocketDatasource(
    debugLabel:
        mode == TrackingMode.client ? 'tracking-client' : 'tracking-driver',
    storageService: ref.watch(secureStorageServiceProvider),
  );
  ref.onDispose(() {
    datasource.dispose();
  });
  return datasource;
});
