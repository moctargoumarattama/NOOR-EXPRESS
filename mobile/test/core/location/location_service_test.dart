import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:noor_express_mobile/core/location/location_service.dart';

void main() {
  group('LocationService.streamPosition', () {
    test('supports a long-lived tracking stream without requiring a timeout',
        () async {
      final geolocatorGateway = _FakeGeolocatorGateway(
        positionStream: Stream<Position>.fromFuture(
          Future<Position>.delayed(
            const Duration(milliseconds: 20),
            () => _position(latitude: 13.51, longitude: 2.11),
          ),
        ),
      );
      final service = LocationService(
        geolocatorGateway: geolocatorGateway,
        permissionGateway: const _FakeLocationPermissionGateway(),
      );

      final result = await service
          .streamPosition(
            distanceFilter: 8,
            timeout: null,
          )
          .first;

      expect(result, isA<LocationSuccess<Position>>());
      expect(
        (result as LocationSuccess<Position>).value.latitude,
        closeTo(13.51, 0.0001),
      );
    });
  });

  group('ForegroundLocationService', () {
    test('starts Android foreground tracking after permissions are granted',
        () async {
      final foregroundGateway = _FakeForegroundLocationGateway();
      final service = ForegroundLocationService(
        foregroundGateway: foregroundGateway,
        permissionGateway: const _FakeForegroundTrackingPermissionGateway(
          ForegroundLocationPermissionState.granted,
        ),
      );

      final result = await service.startDriverTracking();

      expect(result, ForegroundLocationStartResult.started);
      expect(foregroundGateway.startCalls, 1);
      expect(foregroundGateway.lastTitle,
          driverForegroundLocationNotificationTitle);
      expect(
          foregroundGateway.lastBody, driverForegroundLocationNotificationBody);
    });

    test('stops Android foreground tracking and clears desired state',
        () async {
      final foregroundGateway = _FakeForegroundLocationGateway();
      final service = ForegroundLocationService(
        foregroundGateway: foregroundGateway,
        permissionGateway: const _FakeForegroundTrackingPermissionGateway(
          ForegroundLocationPermissionState.granted,
        ),
      );

      await service.startDriverTracking();
      await service.stopDriverTracking();
      await service.recoverDriverTrackingIfNeeded();

      expect(foregroundGateway.stopCalls, 1);
      expect(foregroundGateway.startCalls, 1);
    });

    test('recovers Android foreground tracking after native service crash',
        () async {
      final foregroundGateway = _FakeForegroundLocationGateway();
      final service = ForegroundLocationService(
        foregroundGateway: foregroundGateway,
        permissionGateway: const _FakeForegroundTrackingPermissionGateway(
          ForegroundLocationPermissionState.granted,
        ),
      );

      await service.startDriverTracking();
      foregroundGateway.isRunning = false;
      await service.recoverDriverTrackingIfNeeded();

      expect(foregroundGateway.startCalls, 2);
    });
  });
}

class _FakeGeolocatorGateway implements GeolocatorGateway {
  _FakeGeolocatorGateway({required Stream<Position> positionStream})
      : _positionStream = positionStream;

  final Stream<Position> _positionStream;

  @override
  Future<LocationPermission> checkPermission() async {
    return LocationPermission.whileInUse;
  }

  @override
  Future<Position> getCurrentPosition({
    required LocationAccuracy accuracy,
  }) async {
    return _position(latitude: 13.51, longitude: 2.11);
  }

  @override
  Stream<Position> getPositionStream({
    required LocationAccuracy accuracy,
    required int distanceFilter,
  }) {
    return _positionStream;
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
  String? lastTitle;
  String? lastBody;

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
    lastTitle = title;
    lastBody = body;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    isRunning = false;
  }
}

class _FakeForegroundTrackingPermissionGateway
    implements ForegroundLocationPermissionGateway {
  const _FakeForegroundTrackingPermissionGateway(this.state);

  final ForegroundLocationPermissionState state;

  @override
  Future<ForegroundLocationPermissionState> requestTrackingPermissions() async {
    return state;
  }
}

Position _position({
  required double latitude,
  required double longitude,
}) {
  return Position(
    longitude: longitude,
    latitude: latitude,
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
