import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'location_service.dart';

class LocationState {
  const LocationState({
    this.currentPosition,
    required this.isLoading,
    this.error,
  });

  const LocationState.initial() : this(isLoading: false);

  final Position? currentPosition;
  final bool isLoading;
  final LocationFailure? error;

  LocationState copyWith({
    Position? currentPosition,
    bool? isLoading,
    LocationFailure? error,
    bool clearCurrentPosition = false,
    bool clearError = false,
  }) {
    return LocationState(
      currentPosition: clearCurrentPosition
          ? null
          : currentPosition ?? this.currentPosition,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class LocationController extends StateNotifier<LocationState> {
  LocationController({
    required LocationService locationService,
  })  : _locationService = locationService,
        super(const LocationState.initial());

  static const Duration _retryDelay = Duration(seconds: 5);

  final LocationService _locationService;

  StreamSubscription<LocationResult<Position>>? _positionSubscription;
  Timer? _retryTimer;
  bool _trackingEnabled = false;

  Future<void> initLocation() async {
    debugPrint('[LocationController] initLocation:start');
    state = state.copyWith(isLoading: true, clearError: true);

    final permissionState = await _locationService.checkPermission();
    if (permissionState != LocationPermissionState.granted) {
      final requestedState = await _locationService.requestPermission();
      if (requestedState != LocationPermissionState.granted) {
        final failure = LocationFailure.fromPermissionState(requestedState);
        debugPrint(
          '[LocationController] initLocation:permissionFailure type=${failure.type}',
        );
        state = state.copyWith(
          isLoading: false,
          error: failure,
        );
        return;
      }
    }

    await refreshPosition();
  }

  Future<void> refreshPosition() async {
    debugPrint('[LocationController] refreshPosition:start');
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _locationService.getCurrentPosition();
    if (result is LocationSuccess<Position>) {
      debugPrint('[LocationController] refreshPosition:success');
      state = state.copyWith(
        currentPosition: result.value,
        isLoading: false,
        clearError: true,
      );
      return;
    }

    final failure = (result as LocationError<Position>).failure;
    debugPrint(
      '[LocationController] refreshPosition:failure type=${failure.type}',
    );
    state = state.copyWith(
      isLoading: false,
      error: failure,
    );
  }

  Future<void> startTracking() async {
    debugPrint('[LocationController] startTracking:start');
    _trackingEnabled = true;
    _retryTimer?.cancel();
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    state = state.copyWith(isLoading: true, clearError: true);

    _positionSubscription = _locationService.streamPosition().listen(
      (result) {
        if (result is LocationSuccess<Position>) {
          debugPrint('[LocationController] startTracking:update');
          _retryTimer?.cancel();
          state = state.copyWith(
            currentPosition: result.value,
            isLoading: false,
            clearError: true,
          );
          return;
        }

        final failure = (result as LocationError<Position>).failure;
        debugPrint(
          '[LocationController] startTracking:failure type=${failure.type}',
        );
        state = state.copyWith(
          isLoading: false,
          error: failure,
        );
        _scheduleRetryIfNeeded(failure);
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[LocationController] startTracking:streamError $error');
        final failure = LocationFailure(
          type: LocationFailureType.unavailable,
          message: 'Le flux de localisation a rencontre une erreur.',
          cause: error,
        );
        state = state.copyWith(
          isLoading: false,
          error: failure,
        );
        _scheduleRetryIfNeeded(failure);
      },
    );
  }

  Future<void> stopTracking() async {
    debugPrint('[LocationController] stopTracking');
    _trackingEnabled = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    state = state.copyWith(isLoading: false);
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  void _scheduleRetryIfNeeded(LocationFailure failure) {
    if (!_trackingEnabled) {
      return;
    }

    if (!_isTemporaryFailure(failure)) {
      return;
    }

    debugPrint(
      '[LocationController] scheduleRetry type=${failure.type} delay=${_retryDelay.inSeconds}s',
    );
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, () {
      if (!_trackingEnabled) {
        return;
      }
      unawaited(startTracking());
    });
  }

  bool _isTemporaryFailure(LocationFailure failure) {
    return failure.type == LocationFailureType.timeout ||
        failure.type == LocationFailureType.unavailable;
  }
}

final locationProvider =
    StateNotifierProvider<LocationController, LocationState>((ref) {
  return LocationController(
    locationService: ref.watch(locationServiceProvider),
  );
});
