import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/lifecycle/app_lifecycle_recovery_service.dart';
import '../../../../../core/models/realtime_driver_position.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/services/websocket_service.dart';
import '../../../../../core/state/session_controller.dart';
import '../../../../../core/storage/secure_storage_service.dart';
import 'client_home_controller.dart';

class ClientRealtimeState {
  const ClientRealtimeState({
    required this.connectionStatus,
    this.lastMessage,
    this.lastDriverPosition,
  });

  const ClientRealtimeState.initial()
      : this(connectionStatus: WebSocketStatus.disconnected);

  final WebSocketStatus connectionStatus;
  final String? lastMessage;
  final RealtimeDriverPosition? lastDriverPosition;

  ClientRealtimeState copyWith({
    WebSocketStatus? connectionStatus,
    String? lastMessage,
    RealtimeDriverPosition? lastDriverPosition,
    bool clearLastMessage = false,
    bool clearLastDriverPosition = false,
  }) {
    return ClientRealtimeState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      lastMessage: clearLastMessage ? null : lastMessage ?? this.lastMessage,
      lastDriverPosition: clearLastDriverPosition
          ? null
          : lastDriverPosition ?? this.lastDriverPosition,
    );
  }
}

class ClientRealtimeController extends StateNotifier<ClientRealtimeState> {
  ClientRealtimeController({
    required WebSocketService websocketService,
    required SecureStorageService storageService,
    required Ref ref,
    required String baseUrl,
  })  : _websocketService = websocketService,
        _storageService = storageService,
        _ref = ref,
        _baseUrl = baseUrl,
        super(const ClientRealtimeState.initial());

  final WebSocketService _websocketService;
  final SecureStorageService _storageService;
  final Ref _ref;
  final String _baseUrl;

  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<WebSocketStatus>? _statusSubscription;
  int? _currentClientId;
  void Function()? _unregisterLifecycleResume;

  Future<void> start(int clientId) async {
    if (_currentClientId == clientId &&
        state.connectionStatus != WebSocketStatus.disconnected) {
      return;
    }

    await stop();
    _currentClientId = clientId;
    _registerLifecycleResume();

    _statusSubscription = _websocketService.statuses.listen((status) {
      final previousStatus = state.connectionStatus;
      state = state.copyWith(connectionStatus: status);
      if (status == WebSocketStatus.connected &&
          previousStatus == WebSocketStatus.reconnecting) {
        unawaited(_ref.read(clientHomeControllerProvider.notifier).loadRides());
      }
    });

    _messageSubscription = _websocketService.messages.listen((message) async {
      final type = message['type'] as String?;
      final rideId = message['ride_request_id'] as int?;
      final status = message['status'] as String?;

      if (type == 'driver_position_update') {
        state = state.copyWith(
          lastDriverPosition: RealtimeDriverPosition.fromJson(message),
        );
        return;
      }

      if (rideId == null || status == null) {
        return;
      }

      await _ref.read(clientHomeControllerProvider.notifier).refreshRideStatus(
            rideId: rideId,
            status: status,
          );
      state = state.copyWith(lastMessage: _statusLabel(status));
    });

    final token = await _storageService.readToken();
    await _websocketService.connect(
      buildWebSocketUrl(
        _baseUrl,
        '/ws/clients/$clientId',
        queryParameters: token == null ? null : {'token': token},
      ),
    );
  }

  Future<void> stop() async {
    _unregisterLifecycleResume?.call();
    _unregisterLifecycleResume = null;
    await _messageSubscription?.cancel();
    await _statusSubscription?.cancel();
    _messageSubscription = null;
    _statusSubscription = null;
    _currentClientId = null;
    await _websocketService.disconnect();
    state = const ClientRealtimeState.initial();
  }

  void consumeMessage() {
    state = state.copyWith(clearLastMessage: true);
  }

  void consumeDriverPosition() {
    state = state.copyWith(clearLastDriverPosition: true);
  }

  void _registerLifecycleResume() {
    _unregisterLifecycleResume?.call();
    _unregisterLifecycleResume = _ref
        .read(appLifecycleRecoveryServiceProvider)
        .registerResumeHandler('home-client-realtime', _resumeFromLifecycle);
  }

  Future<void> _resumeFromLifecycle() async {
    final clientId = _currentClientId;
    if (clientId == null) {
      return;
    }

    await _reconnectClientSocket(clientId);
    await _ref
        .read(clientHomeControllerProvider.notifier)
        .resumeFromLifecycle();
  }

  Future<void> _reconnectClientSocket(int clientId) async {
    final token = await _storageService.readToken();
    await _websocketService.disconnect();
    await _websocketService.connect(
      buildWebSocketUrl(
        _baseUrl,
        '/ws/clients/$clientId',
        queryParameters: token == null ? null : {'token': token},
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'offered':
        return 'Des offres sont disponibles.';
      case 'accepted':
        return 'Ride acceptee.';
      case 'arrived':
        return 'Le chauffeur est arrive.';
      case 'started':
        return 'Ride demarree.';
      case 'completed':
        return 'Ride terminee.';
      case 'cancelled':
        return 'Ride annulee.';
      case 'pending':
        return 'La ride redevient negotiable.';
      default:
        return 'Statut de ride mis a jour.';
    }
  }
}

final clientRealtimeProvider = StateNotifierProvider.autoDispose<
    ClientRealtimeController, ClientRealtimeState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final controller = ClientRealtimeController(
    websocketService: ref.watch(websocketProvider('client')),
    storageService: ref.watch(secureStorageServiceProvider),
    ref: ref,
    baseUrl: apiClient.baseUrl,
  );
  ref.onDispose(controller.stop);
  return controller;
});
