import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/core/models/app_role.dart';
import 'package:geolocator/geolocator.dart';
import 'package:noor_express_mobile/core/location/location_service.dart';
import 'package:noor_express_mobile/core/network/api_client.dart';
import 'package:noor_express_mobile/core/notifications/fcm_service.dart';
import 'package:noor_express_mobile/core/notifications/local_notification_service.dart';
import 'package:noor_express_mobile/core/notifications/notification_handler.dart';
import 'package:noor_express_mobile/core/state/session_controller.dart';
import 'package:noor_express_mobile/core/storage/secure_storage_service.dart';
import 'package:noor_express_mobile/features/auth/data/auth_repository.dart';
import 'package:noor_express_mobile/features/ride_tracking/data/datasources/tracking_remote_datasource.dart';
import 'package:noor_express_mobile/features/ride_tracking/data/datasources/tracking_websocket_datasource.dart';
import 'package:noor_express_mobile/features/ride_tracking/domain/entities/tracking_state.dart';
import 'package:noor_express_mobile/features/ride_tracking/presentation/controllers/tracking_controller.dart';

void main() {
  test('start stops cleanly if the tracking provider is disposed mid-refresh',
      () async {
    final activeRideCompleter = Completer<Map<String, dynamic>?>();
    final remoteDatasource = _FakeTrackingRemoteDatasource(
      activeRideFuture: activeRideCompleter.future,
    );
    final websocketDatasource = _FakeTrackingWebSocketDatasource();
    final locationService = LocationService(
      geolocatorGateway: _FakeGeolocatorGateway(),
      permissionGateway: const _FakeLocationPermissionGateway(),
    );

    final container = ProviderContainer(
      overrides: [
        trackingRemoteDatasourceProvider.overrideWith((ref) {
          return remoteDatasource;
        }),
        trackingWebsocketDatasourceProvider.overrideWith((ref, mode) {
          return websocketDatasource;
        }),
        locationServiceProvider.overrideWith((ref) {
          return locationService;
        }),
      ],
    );

    final controller = container.read(
      trackingControllerProvider(
        const TrackingControllerScope(mode: TrackingMode.client),
      ).notifier,
    );

    final startFuture = controller.start();

    container.dispose();
    activeRideCompleter.complete(null);

    await expectLater(startFuture, completes);
  });

  test('resumeFromLifecycle resyncs the active ride from the backend',
      () async {
    final remoteDatasource = _CountingTrackingRemoteDatasource();
    final websocketDatasource = _FakeTrackingWebSocketDatasource();
    final locationService = LocationService(
      geolocatorGateway: _FakeGeolocatorGateway(),
      permissionGateway: const _FakeLocationPermissionGateway(),
    );

    final container = ProviderContainer(
      overrides: [
        trackingRemoteDatasourceProvider.overrideWith((ref) {
          return remoteDatasource;
        }),
        trackingWebsocketDatasourceProvider.overrideWith((ref, mode) {
          return websocketDatasource;
        }),
        locationServiceProvider.overrideWith((ref) {
          return locationService;
        }),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      trackingControllerProvider(
        const TrackingControllerScope(mode: TrackingMode.client),
      ).notifier,
    );

    await controller.start();
    expect(remoteDatasource.fetchActiveRideCalls, 1);

    await controller.resumeFromLifecycle();

    expect(websocketDatasource.resumeCalls, 1);
    expect(remoteDatasource.fetchActiveRideCalls, 2);
  });

  test('resumeFromLifecycle clears tracking when backend has no active ride',
      () async {
    final staleRide = _rideJson(id: 42, status: 'accepted');
    final remoteDatasource = _MutableTrackingRemoteDatasource(
      activeRide: staleRide,
      clientRides: [staleRide],
    );
    final websocketDatasource = _FakeTrackingWebSocketDatasource();
    final locationService = LocationService(
      geolocatorGateway: _FakeGeolocatorGateway(),
      permissionGateway: const _FakeLocationPermissionGateway(),
    );

    final container = ProviderContainer(
      overrides: [
        trackingRemoteDatasourceProvider.overrideWith((ref) {
          return remoteDatasource;
        }),
        trackingWebsocketDatasourceProvider.overrideWith((ref, mode) {
          return websocketDatasource;
        }),
        locationServiceProvider.overrideWith((ref) {
          return locationService;
        }),
      ],
    );
    addTearDown(container.dispose);

    final provider = trackingControllerProvider(
      const TrackingControllerScope(mode: TrackingMode.client),
    );
    final controller = container.read(provider.notifier);

    await controller.start();
    expect(container.read(provider).ride?.id, 42);

    remoteDatasource.activeRide = null;

    await controller.resumeFromLifecycle();

    expect(container.read(provider).ride, isNull);
  });

  test('driver tracking starts and stops the foreground location service',
      () async {
    final activeRide = _rideJson(id: 81, status: 'accepted');
    final remoteDatasource = _MutableTrackingRemoteDatasource(
      activeRide: activeRide,
      clientRides: const [],
    );
    final websocketDatasource = _FakeTrackingWebSocketDatasource();
    final foregroundGateway = _FakeForegroundLocationGateway();
    final container = _trackingContainer(
      remoteDatasource: remoteDatasource,
      websocketDatasource: websocketDatasource,
      foregroundGateway: foregroundGateway,
    );
    addTearDown(container.dispose);

    final controller = container.read(
      trackingControllerProvider(
        const TrackingControllerScope(mode: TrackingMode.driver),
      ).notifier,
    );

    await controller.start();
    expect(foregroundGateway.startCalls, 1);

    await controller.stop();
    expect(foregroundGateway.stopCalls, 1);
  });

  test('driver tracking recovers the foreground service after a crash',
      () async {
    final activeRide = _rideJson(id: 82, status: 'started');
    final remoteDatasource = _MutableTrackingRemoteDatasource(
      activeRide: activeRide,
      clientRides: const [],
    );
    final websocketDatasource = _FakeTrackingWebSocketDatasource();
    final foregroundGateway = _FakeForegroundLocationGateway();
    final container = _trackingContainer(
      remoteDatasource: remoteDatasource,
      websocketDatasource: websocketDatasource,
      foregroundGateway: foregroundGateway,
    );
    addTearDown(container.dispose);

    final controller = container.read(
      trackingControllerProvider(
        const TrackingControllerScope(mode: TrackingMode.driver),
      ).notifier,
    );

    await controller.start();
    foregroundGateway.isRunning = false;
    await controller.resumeFromLifecycle();

    expect(foregroundGateway.startCalls, 2);
  });

  test('tracking hydrates unread chat count from the backend summary',
      () async {
    final activeRide = _rideJson(id: 83, status: 'accepted');
    final remoteDatasource = _MutableTrackingRemoteDatasource(
      activeRide: activeRide,
      clientRides: [activeRide],
      unreadChatCount: 2,
    );
    final container = _trackingContainer(
      remoteDatasource: remoteDatasource,
      websocketDatasource: _FakeTrackingWebSocketDatasource(),
      foregroundGateway: _FakeForegroundLocationGateway(),
    );
    addTearDown(container.dispose);

    final provider = trackingControllerProvider(
      const TrackingControllerScope(mode: TrackingMode.client),
    );
    final controller = container.read(provider.notifier);

    await controller.start();

    expect(container.read(provider).unreadChatCount, 2);
  });
}

ProviderContainer _trackingContainer({
  required TrackingRemoteDatasource remoteDatasource,
  required TrackingWebSocketDatasource websocketDatasource,
  required _FakeForegroundLocationGateway foregroundGateway,
}) {
  final locationService = LocationService(
    geolocatorGateway: _FakeGeolocatorGateway(),
    permissionGateway: const _FakeLocationPermissionGateway(),
  );
  final foregroundService = ForegroundLocationService(
    foregroundGateway: foregroundGateway,
    permissionGateway: const _FakeForegroundTrackingPermissionGateway(),
  );
  return ProviderContainer(
    overrides: [
      sessionControllerProvider.overrideWith((ref) {
        return _FakeSessionController();
      }),
      trackingRemoteDatasourceProvider.overrideWith((ref) {
        return remoteDatasource;
      }),
      trackingWebsocketDatasourceProvider.overrideWith((ref, mode) {
        return websocketDatasource;
      }),
      locationServiceProvider.overrideWith((ref) {
        return locationService;
      }),
      foregroundLocationServiceProvider.overrideWith((ref) {
        return foregroundService;
      }),
    ],
  );
}

class _FakeTrackingRemoteDatasource extends TrackingRemoteDatasource {
  _FakeTrackingRemoteDatasource({
    required Future<Map<String, dynamic>?> activeRideFuture,
  })  : _activeRideFuture = activeRideFuture,
        super(apiClient: ApiClient());

  final Future<Map<String, dynamic>?> _activeRideFuture;

  @override
  Future<Map<String, dynamic>?> fetchActiveRide() {
    return _activeRideFuture;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchClientRides() async {
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchDriverRides() async {
    return const [];
  }
}

class _FakeTrackingWebSocketDatasource extends TrackingWebSocketDatasource {
  _FakeTrackingWebSocketDatasource()
      : super(
          debugLabel: 'test-tracking',
          storageService: const SecureStorageService(),
        );

  final StreamController<TrackingSocketEvent> _events =
      StreamController<TrackingSocketEvent>.broadcast();
  final StreamController<TrackingConnectionState> _states =
      StreamController<TrackingConnectionState>.broadcast();
  int resumeCalls = 0;

  @override
  Stream<TrackingSocketEvent> get events => _events.stream;

  @override
  Stream<TrackingConnectionState> get connectionStates => _states.stream;

  @override
  Future<void> connectForClient(int clientId) async {}

  @override
  Future<void> connectForDriver(int driverId) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> resumeFromLifecycle() async {
    resumeCalls += 1;
  }

  void emitEvent(TrackingSocketEvent event) {
    _events.add(event);
  }
}

class _CountingTrackingRemoteDatasource extends TrackingRemoteDatasource {
  _CountingTrackingRemoteDatasource() : super(apiClient: ApiClient());

  int fetchActiveRideCalls = 0;

  @override
  Future<Map<String, dynamic>?> fetchActiveRide() async {
    fetchActiveRideCalls += 1;
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchClientRides() async {
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchDriverRides() async {
    return const [];
  }
}

class _MutableTrackingRemoteDatasource extends TrackingRemoteDatasource {
  _MutableTrackingRemoteDatasource({
    required this.activeRide,
    required this.clientRides,
    this.unreadChatCount = 0,
  }) : super(apiClient: ApiClient());

  Map<String, dynamic>? activeRide;
  List<Map<String, dynamic>> clientRides;
  int unreadChatCount;

  @override
  Future<Map<String, dynamic>?> fetchActiveRide() async {
    return activeRide;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchClientRides() async {
    return clientRides;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchDriverRides() async {
    return const [];
  }

  @override
  Future<Map<String, dynamic>> fetchRideMessages({
    required int rideId,
    int limit = 50,
    int offset = 0,
    bool markRead = true,
  }) async {
    return {
      'items': const [],
      'unread_count': unreadChatCount,
      'limit': limit,
      'offset': offset,
    };
  }

  @override
  Future<Map<String, dynamic>> fetchUser(int userId) async {
    return {
      'id': userId,
      'name': 'Client Noor',
      'phone_number': '+22790000000',
    };
  }
}

class _FakeSessionController extends SessionController {
  _FakeSessionController()
      : super(
          authRepository: AuthRepository(apiClient: ApiClient()),
          apiClient: ApiClient(),
          fcmService: FcmService(
            apiClient: ApiClient(),
            localNotificationService: LocalNotificationService(),
            notificationHandler: NotificationHandler(),
          ),
          storageService: const SecureStorageService(),
        ) {
    state = const SessionState(
      status: SessionStatus.authenticated,
      userId: 7,
      role: AppRole.client,
      token: 'token',
    );
  }
}

class _FakeGeolocatorGateway implements GeolocatorGateway {
  @override
  Future<LocationPermission> checkPermission() async {
    return LocationPermission.whileInUse;
  }

  @override
  Future<Position> getCurrentPosition({
    required LocationAccuracy accuracy,
  }) async {
    return _position();
  }

  @override
  Stream<Position> getPositionStream({
    required LocationAccuracy accuracy,
    required int distanceFilter,
  }) {
    return const Stream<Position>.empty();
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    return true;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    return LocationPermission.whileInUse;
  }
}

class _FakeLocationPermissionGateway implements LocationPermissionGateway {
  const _FakeLocationPermissionGateway();

  @override
  Future<bool> openAppSettings() async {
    return true;
  }
}

class _FakeForegroundLocationGateway implements ForegroundLocationGateway {
  int startCalls = 0;
  int stopCalls = 0;
  bool isRunning = false;

  @override
  Future<bool> get isServiceRunning async {
    return isRunning;
  }

  @override
  Future<void> start({
    required String title,
    required String body,
  }) async {
    startCalls += 1;
    isRunning = true;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    isRunning = false;
  }
}

class _FakeForegroundTrackingPermissionGateway
    implements ForegroundLocationPermissionGateway {
  const _FakeForegroundTrackingPermissionGateway();

  @override
  Future<ForegroundLocationPermissionState> requestTrackingPermissions() async {
    return ForegroundLocationPermissionState.granted;
  }
}

Position _position() {
  return Position(
    longitude: 2.11,
    latitude: 13.51,
    timestamp: DateTime(2026, 4, 24, 10),
    accuracy: 4,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

Map<String, dynamic> _rideJson({
  required int id,
  required String status,
}) {
  return {
    'id': id,
    'client_id': 7,
    'pickup_location': 'Grand Marche',
    'dropoff_location': 'Aeroport',
    'estimated_price': 2500,
    'created_at': '2026-04-24T10:00:00Z',
    'status': status,
  };
}
