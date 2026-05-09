import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/location/device_location_service.dart';
import '../../../../../core/lifecycle/app_lifecycle_recovery_service.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/services/websocket_service.dart';
import '../../../../../core/state/session_controller.dart';
import '../../../../../core/storage/secure_storage_service.dart';
import 'ride_driver_controller.dart';

class DriverRealtimeState {
  const DriverRealtimeState({
    required this.connectionStatus,
    this.lastMessage,
    this.pendingRideId,
    this.pendingRidePayload,
    this.lastPositionSentAt,
    this.hasPositionFix = false,
    this.locationProblemDetected = false,
  });

  const DriverRealtimeState.initial()
      : this(connectionStatus: WebSocketStatus.disconnected);

  final WebSocketStatus connectionStatus;
  final String? lastMessage;
  final int? pendingRideId;
  final Map<String, dynamic>? pendingRidePayload;
  final DateTime? lastPositionSentAt;
  final bool hasPositionFix;
  final bool locationProblemDetected;

  DriverRealtimeState copyWith({
    WebSocketStatus? connectionStatus,
    String? lastMessage,
    int? pendingRideId,
    Map<String, dynamic>? pendingRidePayload,
    DateTime? lastPositionSentAt,
    bool? hasPositionFix,
    bool? locationProblemDetected,
    bool clearLastMessage = false,
    bool clearPendingRide = false,
    bool clearGpsState = false,
  }) {
    return DriverRealtimeState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      lastMessage: clearLastMessage ? null : lastMessage ?? this.lastMessage,
      pendingRideId:
          clearPendingRide ? null : pendingRideId ?? this.pendingRideId,
      pendingRidePayload: clearPendingRide
          ? null
          : pendingRidePayload ?? this.pendingRidePayload,
      lastPositionSentAt:
          clearGpsState ? null : lastPositionSentAt ?? this.lastPositionSentAt,
      hasPositionFix:
          clearGpsState ? false : hasPositionFix ?? this.hasPositionFix,
      locationProblemDetected: clearGpsState
          ? false
          : locationProblemDetected ?? this.locationProblemDetected,
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
  StreamSubscription<DevicePosition>? _positionSubscription;
  Timer? _ridesRefreshTimer;
  int? _currentDriverId;
  void Function()? _unregisterLifecycleResume;

  Future<void> start(int driverId) async {
    if (_currentDriverId == driverId &&
        state.connectionStatus != WebSocketStatus.disconnected) {
      return;
    }

    await stop();
    _currentDriverId = driverId;
    _registerLifecycleResume();

    _statusSubscription = _websocketService.statuses.listen((status) {
      final previousStatus = state.connectionStatus;
      state = state.copyWith(connectionStatus: status);
      if (status == WebSocketStatus.connected) {
        _startLocationSharing();
        if (previousStatus == WebSocketStatus.reconnecting) {
          _scheduleRidesRefresh();
        }
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
    _unregisterLifecycleResume?.call();
    _unregisterLifecycleResume = null;
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

  void _registerLifecycleResume() {
    _unregisterLifecycleResume?.call();
    _unregisterLifecycleResume = _ref
        .read(appLifecycleRecoveryServiceProvider)
        .registerResumeHandler('home-driver-realtime', _resumeFromLifecycle);
  }

  Future<void> _resumeFromLifecycle() async {
    final driverId = _currentDriverId;
    if (driverId == null) {
      return;
    }

    await _reconnectDriverSocket(driverId);
    await _ref.read(rideDriverProvider.notifier).resumeFromLifecycle();
  }

  Future<void> _reconnectDriverSocket(int driverId) async {
    final token = await _storageService.readToken();
    await _websocketService.disconnect();
    await _websocketService.connect(
      buildWebSocketUrl(
        _baseUrl,
        '/ws/drivers/$driverId',
        queryParameters: token == null ? null : {'token': token},
      ),
    );
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

    final locationService = _ref.read(deviceLocationServiceProvider);
    final accessState = await locationService.ensurePermission();
    if (accessState != DeviceLocationAccessState.granted) {
      state = state.copyWith(
        locationProblemDetected: true,
        lastMessage:
            'GPS inactif. Activez la localisation pour recevoir des courses.',
      );
      return;
    }

    final currentPosition = await locationService.getCurrentPosition();
    if (currentPosition != null) {
      _sendPosition(
        latitude: currentPosition.latitude,
        longitude: currentPosition.longitude,
      );
    } else {
      state = state.copyWith(
        locationProblemDetected: true,
        lastMessage: 'Votre position GPS est indisponible pour le moment.',
      );
    }

    _positionSubscription = locationService.watchPosition().listen(
      (position) => _sendPosition(
        latitude: position.latitude,
        longitude: position.longitude,
      ),
      onError: (_) {
        state = state.copyWith(
          locationProblemDetected: true,
          lastMessage: 'Votre position ne s envoie plus pour le moment.',
        );
      },
      onDone: () {
        state = state.copyWith(locationProblemDetected: true);
      },
    );
  }

  void _sendPosition({
    required double latitude,
    required double longitude,
  }) {
    state = state.copyWith(
      lastPositionSentAt: DateTime.now(),
      hasPositionFix: true,
      locationProblemDetected: false,
    );
    _websocketService.sendJson(
      {
        'type': 'location_update',
        'lat': latitude,
        'lng': longitude,
      },
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'Vous avez une nouvelle course.';
      case 'arrived':
        return 'Vous etes arrive chez le client.';
      case 'started':
        return 'Le trajet est en cours.';
      case 'completed':
        return 'Le trajet est termine.';
      case 'cancelled':
        return 'Le trajet a ete annule.';
      case 'pending':
        return 'La demande revient dans la liste.';
      default:
        return 'Le trajet vient d etre mis a jour.';
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
