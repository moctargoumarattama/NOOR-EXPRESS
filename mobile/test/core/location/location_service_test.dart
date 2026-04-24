import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:noor_express_mobile/core/location/location_service.dart';

void main() {
  group('LocationService.streamPosition', () {
    test('supports a long-lived tracking stream without requiring a timeout', () async {
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

      final result = await service.streamPosition(
        distanceFilter: 8,
        timeout: null,
      ).first;

      expect(result, isA<LocationSuccess<Position>>());
      expect(
        (result as LocationSuccess<Position>).value.latitude,
        closeTo(13.51, 0.0001),
      );
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
