import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/network/api_client.dart';
import '../../../../../core/services/websocket_service.dart';
import '../../../../../core/state/session_controller.dart';
import '../../../../../core/storage/secure_storage_service.dart';
import '../../../../map/services/location_service.dart';
import 'ride_driver_controller.dart';

class DriverRealtimeState {
  const DriverRealtimeState({
    required this.connectionStatus,
    this.lastMessage,
    this.pendingRideId,
    this.pendingRidePayload,
  });

  const DriverRealtimeState.initial()
      : this(connectionStatus: WebSocketStatus.disconnected);

  final WebSocketStatus connectionStatus;
  final String? lastMessage;
  final int? pendingRideId;
  final Map<String, dynamic>? pendingRidePayload;

  DriverRealtimeState copyWith({
    WebSocketStatus? connectionStatus,
    String? lastMessage,
    int? pendingRideId,
    Map<String, dynamic>? pendingRidePayload,
    bool clearLastMessage = false,
    bool clearPendingRide = false,
  }) {
    return DriverRealtimeState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      lastMessage: clearLastMessage ? null : lastMessage ?? this.lastMessage,
      pendingRideId:
          clearPendingRide ? null : pendingRideId ?? this.pendingRideId,
      pendingRidePayload: clearPendingRide
          ? null
          : pendingRidePayload ?? this.pendingRidePayload,
    );
  }
}

class DriverRealtimeController extends StateNotifier<DriverRealtimeState> {
  DriverRealtimeController({
    required WebSocketService websocketService,
    required SecureStorageService storageService,
    required Ref ref,
    required String baseUrl,
  })  : _websocketService = websocketService,
        _storageService = storageService,
        _ref = ref,
        _baseUrl = baseUrl,
        super(const DriverRealtimeState.initial());

  final WebSocketService _websocketService;
  final SecureStorageService _storageService;
  final Ref _ref;
  final String _baseUrl;

  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<WebSocketStatus>? _statusSubscription;
  StreamSubscription<LatLng>? _positionSubscription;
  Timer? _ridesRefreshTimer;
  int? _currentDriverId;

  Future<void> start(int driverId) async {
    if (_currentDriverId == driverId &&
        state.connectionStatus != WebSocketStatus.disconnected) {
      return;
    }

    await stop();
    _currentDriverId = driverId;

    _statusSubscription = _websocketService.statuses.listen((status) {
      state = state.copyWith(connectionStatus: status);
      if (status == WebSocketStatus.connected) {
        _startLocationSharing();
      } else {
        _positionSubscription?.cancel();
        _positionSubscription = null;
      }
    });

    _messageSubscription = _websocketService.messages.listen((message) {
      final type = message['type'] as String?;
      final status = message['status'] as String?;

      if (type == 'new_ride_request') {
        _scheduleRidesRefresh(
          includeAvailableRides: true,
          includeHistory: false,
        );
        state = state.copyWith(
          lastMessage: 'Nouvelle demande de course.',
          pendingRideId:
              ((message['ride_id'] ?? message['ride_request_id']) as num?)
                  ?.toInt(),
          pendingRidePayload: message,
        );
        return;
      }

      if (status != null) {
        _scheduleRidesRefresh();
        state = state.copyWith(
          lastMessage: _statusLabel(status),
        );
      }
    });

    final token = await _storageService.readToken();
    await _websocketService.connect(
      buildWebSocketUrl(
        _baseUrl,
        '/ws/drivers/$driverId',
        queryParameters: token == null ? null : {'token': token},
      ),
    );
  }

  Future<void> stop() async {
    _ridesRefreshTimer?.cancel();
    _ridesRefreshTimer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await _messageSubscription?.cancel();
    await _statusSubscription?.cancel();
    _messageSubscription = null;
    _statusSubscription = null;
    _currentDriverId = null;
    await _websocketService.disconnect();
    state = const DriverRealtimeState.initial();
  }

  void consumeMessage() {
    state = state.copyWith(clearLastMessage: true);
  }

  void consumePendingRide() {
    state = state.copyWith(clearPendingRide: true);
  }

  void _scheduleRidesRefresh({
    bool includeAvailableRides = true,
    bool includeHistory = true,
  }) {
    _ridesRefreshTimer?.cancel();
    _ridesRefreshTimer = Timer(const Duration(milliseconds: 250), () {
      _ref.read(rideDriverProvider.notifier).refreshRealtimeSnapshot(
            includeAvailableRides: includeAvailableRides,
            includeHistory: includeHistory,
          );
    });
  }

  Future<void> _startLocationSharing() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    final locationService = _ref.read(mapLocationServiceProvider);
    final currentPosition = await locationService.getCurrentPosition();
    _sendPosition(currentPosition);

    _positionSubscription = locationService.watchPosition().listen(
      _sendPosition,
      onError: (_) {
        state = state.copyWith(
          lastMessage: 'Le tracking GPS driver a ete interrompu.',
        );
      },
    );
  }

  void _sendPosition(LatLng position) {
    _websocketService.sendJson(
      {
        'type': 'location_update',
        'lat': position.latitude,
        'lng': position.longitude,
      },
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'Une ride a ete acceptee.';
      case 'started':
        return 'Une course est en cours.';
      case 'completed':
        return 'Une course a ete terminee.';
      case 'cancelled':
        return 'Une ride a ete annulee.';
      default:
        return 'Statut de ride mis a jour.';
    }
  }
}

final driverRealtimeProvider = StateNotifierProvider.autoDispose<
    DriverRealtimeController, DriverRealtimeState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final controller = DriverRealtimeController(
    websocketService: ref.watch(websocketProvider('driver')),
    storageService: ref.watch(secureStorageServiceProvider),
    ref: ref,
    baseUrl: apiClient.baseUrl,
  );
  ref.onDispose(controller.stop);
  return controller;
});
