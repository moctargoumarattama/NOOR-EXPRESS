import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/core/lifecycle/app_lifecycle_recovery_service.dart';
import 'package:noor_express_mobile/core/network/api_client.dart';
import 'package:noor_express_mobile/core/services/websocket_service.dart';
import 'package:noor_express_mobile/core/state/session_controller.dart';
import 'package:noor_express_mobile/core/storage/secure_storage_service.dart';
import 'package:noor_express_mobile/features/home/client/data/client_rides_repository.dart';
import 'package:noor_express_mobile/features/home/client/data/models/client_ride.dart';
import 'package:noor_express_mobile/features/home/client/presentation/controllers/client_realtime_controller.dart';

void main() {
  test('new_offer websocket events resync home and expose an offer message',
      () async {
    final websocket = _FakeWebSocketService();
    final repository = _FakeClientRidesRepository(
      activeRide: _ride(status: 'offered'),
    );
    final container = ProviderContainer(
      overrides: [
        websocketProvider.overrideWith((ref, scope) => websocket),
        secureStorageServiceProvider.overrideWith(
          (ref) => const _FakeSecureStorageService(),
        ),
        clientRidesRepositoryProvider.overrideWith((ref) => repository),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      clientRealtimeProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final controller = container.read(clientRealtimeProvider.notifier);
    await controller.start(7);

    websocket.emitMessage({
      'type': 'new_offer',
      'offer': {
        'ride_id': 42,
        'offer_id': 9,
      },
    });
    await Future<void>.delayed(const Duration(milliseconds: 1));

    expect(repository.fetchMyRidesCalls, 1);
    expect(repository.fetchActiveRideCalls, 1);
    expect(
      container.read(clientRealtimeProvider).lastMessage,
      'Nouvelle proposition recue.',
    );
  });

  test('paused -> resumed reconnects websocket and resyncs active ride',
      () async {
    final websocket = _FakeWebSocketService();
    final repository = _FakeClientRidesRepository(
      activeRide: _ride(status: 'accepted'),
    );
    final container = ProviderContainer(
      overrides: [
        websocketProvider.overrideWith((ref, scope) => websocket),
        secureStorageServiceProvider.overrideWith(
          (ref) => const _FakeSecureStorageService(),
        ),
        clientRidesRepositoryProvider.overrideWith((ref) => repository),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      clientRealtimeProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container.read(clientRealtimeProvider.notifier).start(7);
    expect(websocket.connectCalls, 1);

    final lifecycle = container.read(appLifecycleRecoveryServiceProvider);
    await lifecycle.onLifecycleStateChanged(AppLifecycleState.paused);
    await lifecycle.onLifecycleStateChanged(AppLifecycleState.resumed);

    expect(websocket.connectCalls, 2);
    expect(websocket.disconnectCalls, 2);
    expect(repository.fetchMyRidesCalls, 1);
    expect(repository.fetchActiveRideCalls, 1);
  });
}

class _FakeWebSocketService extends WebSocketService {
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _statuses = StreamController<WebSocketStatus>.broadcast();
  int connectCalls = 0;
  int disconnectCalls = 0;

  @override
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  @override
  Stream<WebSocketStatus> get statuses => _statuses.stream;

  @override
  Future<void> connect(String url) async {
    connectCalls += 1;
    _statuses.add(WebSocketStatus.connected);
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
    _statuses.add(WebSocketStatus.disconnected);
  }

  void emitMessage(Map<String, dynamic> message) {
    _messages.add(message);
  }

  @override
  Future<void> dispose() async {
    await _messages.close();
    await _statuses.close();
  }
}

class _FakeSecureStorageService extends SecureStorageService {
  const _FakeSecureStorageService();

  @override
  Future<String?> readToken() async => 'token';
}

class _FakeClientRidesRepository extends ClientRidesRepository {
  _FakeClientRidesRepository({required this.activeRide})
      : super(apiClient: ApiClient());

  final ClientRide activeRide;
  int fetchMyRidesCalls = 0;
  int fetchActiveRideCalls = 0;

  @override
  Future<List<ClientRide>> fetchMyRides({
    int limit = 100,
    int offset = 0,
  }) async {
    fetchMyRidesCalls += 1;
    return [activeRide];
  }

  @override
  Future<ClientRide?> fetchActiveRide() async {
    fetchActiveRideCalls += 1;
    return activeRide;
  }
}

ClientRide _ride({required String status}) {
  return ClientRide(
    id: 42,
    pickupLocation: 'Grand Marche',
    dropoffLocation: 'Aeroport',
    status: status,
    estimatedPrice: 2500,
    createdAt: DateTime(2026, 4, 24, 10),
  );
}
