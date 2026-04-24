import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;

enum LocationPermissionState {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

enum LocationFailureType {
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  timeout,
  unavailable,
  unknown,
}

class LocationFailure {
  const LocationFailure({
    required this.type,
    required this.message,
    this.cause,
  });

  final LocationFailureType type;
  final String message;
  final Object? cause;

  factory LocationFailure.fromPermissionState(LocationPermissionState state) {
    switch (state) {
      case LocationPermissionState.denied:
        return const LocationFailure(
          type: LocationFailureType.permissionDenied,
          message: 'La permission de localisation a ete refusee.',
        );
      case LocationPermissionState.deniedForever:
        return const LocationFailure(
          type: LocationFailureType.permissionDeniedForever,
          message: 'La permission de localisation est refusee definitivement.',
        );
      case LocationPermissionState.serviceDisabled:
        return const LocationFailure(
          type: LocationFailureType.serviceDisabled,
          message: 'Le service de localisation est desactive.',
        );
      case LocationPermissionState.granted:
        return const LocationFailure(
          type: LocationFailureType.unknown,
          message: 'Etat de localisation inattendu.',
        );
    }
  }
}

sealed class LocationResult<T> {
  const LocationResult();

  bool get isSuccess => this is LocationSuccess<T>;
  bool get isFailure => this is LocationError<T>;
}

class LocationSuccess<T> extends LocationResult<T> {
  const LocationSuccess(this.value);

  final T value;
}

class LocationError<T> extends LocationResult<T> {
  const LocationError(this.failure);

  final LocationFailure failure;
}

abstract class GeolocatorGateway {
  Future<bool> isLocationServiceEnabled();

  Future<LocationPermission> checkPermission();

  Future<LocationPermission> requestPermission();

  Future<Position> getCurrentPosition({
    required LocationAccuracy accuracy,
  });

  Stream<Position> getPositionStream({
    required LocationAccuracy accuracy,
    required int distanceFilter,
  });

  Future<bool> openLocationSettings();
}

class DefaultGeolocatorGateway implements GeolocatorGateway {
  const DefaultGeolocatorGateway();

  @override
  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<LocationPermission> checkPermission() {
    return Geolocator.checkPermission();
  }

  @override
  Future<LocationPermission> requestPermission() {
    return Geolocator.requestPermission();
  }

  @override
  Future<Position> getCurrentPosition({
    required LocationAccuracy accuracy,
  }) {
    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(accuracy: accuracy),
    );
  }

  @override
  Stream<Position> getPositionStream({
    required LocationAccuracy accuracy,
    required int distanceFilter,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    );
  }

  @override
  Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }
}

abstract class LocationPermissionGateway {
  Future<bool> openAppSettings();
}

class DefaultLocationPermissionGateway implements LocationPermissionGateway {
  const DefaultLocationPermissionGateway();

  @override
  Future<bool> openAppSettings() {
    return permission_handler.openAppSettings();
  }
}

class LocationService {
  LocationService({
    required GeolocatorGateway geolocatorGateway,
    required LocationPermissionGateway permissionGateway,
  })  : _geolocatorGateway = geolocatorGateway,
        _permissionGateway = permissionGateway;

  final GeolocatorGateway _geolocatorGateway;
  final LocationPermissionGateway _permissionGateway;

  Future<LocationPermissionState> checkPermission() async {
    debugPrint('[LocationService] checkPermission:start');

    final isServiceEnabled =
        await _geolocatorGateway.isLocationServiceEnabled();
    if (!isServiceEnabled) {
      debugPrint('[LocationService] checkPermission:serviceDisabled');
      return LocationPermissionState.serviceDisabled;
    }

    final status = await _geolocatorGateway.checkPermission();
    final mapped = _mapGeolocatorPermission(status);
    debugPrint('[LocationService] checkPermission:status=$mapped');
    return mapped;
  }

  Future<LocationPermissionState> requestPermission() async {
    debugPrint('[LocationService] requestPermission:start');

    final isServiceEnabled =
        await _geolocatorGateway.isLocationServiceEnabled();
    if (!isServiceEnabled) {
      debugPrint('[LocationService] requestPermission:serviceDisabled');
      return LocationPermissionState.serviceDisabled;
    }

    final currentStatus = await _geolocatorGateway.checkPermission();
    if (_isGeolocatorGranted(currentStatus)) {
      debugPrint('[LocationService] requestPermission:alreadyGranted');
      return LocationPermissionState.granted;
    }

    if (currentStatus == LocationPermission.deniedForever) {
      debugPrint('[LocationService] requestPermission:deniedForever');
      return LocationPermissionState.deniedForever;
    }

    final requestedStatus = await _geolocatorGateway.requestPermission();
    final mapped = _mapGeolocatorPermission(requestedStatus);
    debugPrint('[LocationService] requestPermission:status=$mapped');
    return mapped;
  }

  Future<LocationResult<Position>> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    debugPrint(
      '[LocationService] getCurrentPosition:start accuracy=$accuracy timeout=${timeout.inSeconds}s',
    );

    final permissionState = await requestPermission();
    if (permissionState != LocationPermissionState.granted) {
      final failure = LocationFailure.fromPermissionState(permissionState);
      debugPrint(
        '[LocationService] getCurrentPosition:failure type=${failure.type}',
      );
      return LocationError<Position>(failure);
    }

    try {
      final position = await _geolocatorGateway
          .getCurrentPosition(accuracy: accuracy)
          .timeout(timeout);
      debugPrint(
        '[LocationService] getCurrentPosition:success lat=${position.latitude} lng=${position.longitude}',
      );
      return LocationSuccess<Position>(position);
    } on TimeoutException catch (error) {
      debugPrint('[LocationService] getCurrentPosition:timeout $error');
      return LocationError<Position>(
        LocationFailure(
          type: LocationFailureType.timeout,
          message: 'La recuperation de la position a expire.',
          cause: error,
        ),
      );
    } on LocationServiceDisabledException catch (error) {
      debugPrint('[LocationService] getCurrentPosition:serviceDisabled $error');
      return LocationError<Position>(
        LocationFailure(
          type: LocationFailureType.serviceDisabled,
          message: 'Le service de localisation est desactive.',
          cause: error,
        ),
      );
    } catch (error) {
      debugPrint('[LocationService] getCurrentPosition:unknownError $error');
      return LocationError<Position>(
        LocationFailure(
          type: LocationFailureType.unavailable,
          message: 'Impossible de recuperer la position actuelle.',
          cause: error,
        ),
      );
    }
  }

  Stream<LocationResult<Position>> streamPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10,
    Duration? timeout,
  }) async* {
    debugPrint(
      '[LocationService] streamPosition:start accuracy=$accuracy distanceFilter=$distanceFilter timeout=${timeout?.inSeconds ?? 'none'}s',
    );

    final permissionState = await requestPermission();
    if (permissionState != LocationPermissionState.granted) {
      final failure = LocationFailure.fromPermissionState(permissionState);
      debugPrint(
        '[LocationService] streamPosition:failure type=${failure.type}',
      );
      yield LocationError<Position>(failure);
      return;
    }

    try {
      final positionStream = _geolocatorGateway.getPositionStream(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      );
      final trackedStream =
          timeout == null ? positionStream : positionStream.timeout(timeout);

      await for (final position in trackedStream) {
        debugPrint(
          '[LocationService] streamPosition:update lat=${position.latitude} lng=${position.longitude}',
        );
        yield LocationSuccess<Position>(position);
      }
    } on TimeoutException catch (error) {
      debugPrint('[LocationService] streamPosition:timeout $error');
      yield LocationError<Position>(
        LocationFailure(
          type: LocationFailureType.timeout,
          message: 'Le flux de localisation a expire.',
          cause: error,
        ),
      );
    } on LocationServiceDisabledException catch (error) {
      debugPrint('[LocationService] streamPosition:serviceDisabled $error');
      yield LocationError<Position>(
        LocationFailure(
          type: LocationFailureType.serviceDisabled,
          message: 'Le service de localisation est desactive.',
          cause: error,
        ),
      );
    } catch (error) {
      debugPrint('[LocationService] streamPosition:unknownError $error');
      yield LocationError<Position>(
        LocationFailure(
          type: LocationFailureType.unavailable,
          message: 'Impossible de suivre la position en temps reel.',
          cause: error,
        ),
      );
    }
  }

  Future<bool> openAppSettings() async {
    debugPrint('[LocationService] openAppSettings');
    return _permissionGateway.openAppSettings();
  }

  Future<bool> openLocationSettings() async {
    debugPrint('[LocationService] openLocationSettings');
    return _geolocatorGateway.openLocationSettings();
  }

  LocationPermissionState _mapGeolocatorPermission(LocationPermission status) {
    switch (status) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionState.granted;
      case LocationPermission.deniedForever:
        return LocationPermissionState.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationPermissionState.denied;
    }
  }

  bool _isGeolocatorGranted(LocationPermission status) {
    return status == LocationPermission.always ||
        status == LocationPermission.whileInUse;
  }
}

final geolocatorGatewayProvider = Provider<GeolocatorGateway>((ref) {
  return const DefaultGeolocatorGateway();
});

final locationPermissionGatewayProvider =
    Provider<LocationPermissionGateway>((ref) {
  return const DefaultLocationPermissionGateway();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService(
    geolocatorGateway: ref.watch(geolocatorGatewayProvider),
    permissionGateway: ref.watch(locationPermissionGatewayProvider),
  );
});
