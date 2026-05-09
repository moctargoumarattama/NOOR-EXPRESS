import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'location_service.dart';

class DevicePosition {
  const DevicePosition({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
}

enum DeviceLocationAccessState {
  initial,
  requesting,
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

class DeviceLocationService {
  DeviceLocationService({required LocationService locationService})
      : _locationService = locationService;

  final LocationService _locationService;

  Future<DeviceLocationAccessState> ensurePermission() async {
    final permissionState = await _locationService.requestPermission();
    switch (permissionState) {
      case LocationPermissionState.granted:
        return DeviceLocationAccessState.granted;
      case LocationPermissionState.denied:
        return DeviceLocationAccessState.denied;
      case LocationPermissionState.deniedForever:
        return DeviceLocationAccessState.deniedForever;
      case LocationPermissionState.serviceDisabled:
        return DeviceLocationAccessState.serviceDisabled;
    }
  }

  Future<DevicePosition?> getCurrentPosition() async {
    final result = await _locationService.getCurrentPosition(
      accuracy: LocationAccuracy.high,
    );
    if (result is! LocationSuccess<Position>) {
      return null;
    }

    final position = result.value;

    return DevicePosition(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
    );
  }

  Stream<DevicePosition> watchPosition() async* {
    await for (final result in _locationService.streamPosition(
      accuracy: LocationAccuracy.high,
      distanceFilter: 8,
    )) {
      if (result is! LocationSuccess<Position>) {
        continue;
      }

      final position = result.value;
      yield DevicePosition(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
    }
  }

  Future<void> openAppSettings() async {
    await _locationService.openAppSettings();
  }

  Future<void> openLocationSettings() async {
    await _locationService.openLocationSettings();
  }
}

final deviceLocationServiceProvider = Provider<DeviceLocationService>((ref) {
  return DeviceLocationService(
    locationService: ref.watch(locationServiceProvider),
  );
});
