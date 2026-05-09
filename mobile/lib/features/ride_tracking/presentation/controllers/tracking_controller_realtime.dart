part of 'tracking_controller.dart';

const _foregroundLocationPermissionMessage =
    'Autorisez la localisation en arriere-plan pour suivre la course.';

Future<void> _bindRealtime(TrackingController controller) async {
  if (!controller._isActive) {
    return;
  }
  final session = controller.ref.read(sessionControllerProvider);
  final userId = session.userId;
  if (userId == null) {
    return;
  }

  await controller._eventSubscription?.cancel();
  await controller._connectionSubscription?.cancel();
  controller._connectionSubscription =
      controller._websocketDatasource.connectionStates.listen(
    (connectionState) {
      if (!controller._isActive) {
        return;
      }
      final previousState = controller._currentStateOrNull;
      if (previousState == null) {
        return;
      }
      final previousConnectionState = previousState.connectionState;
      controller._setStateIfAlive(previousState.copyWith(
        connectionState: connectionState,
        clearError: connectionState == TrackingConnectionState.connected,
      ));
      if (connectionState == TrackingConnectionState.connected &&
          previousConnectionState == TrackingConnectionState.reconnecting) {
        unawaited(_refreshSnapshot(controller));
      }
      if (connectionState == TrackingConnectionState.connected &&
          controller.mode == TrackingMode.driver) {
        final currentPosition = controller._currentStateOrNull?.currentPosition;
        if (currentPosition != null) {
          controller._websocketDatasource.sendLocationUpdate(currentPosition);
        }
      }
    },
  );
  controller._eventSubscription = controller._websocketDatasource.events.listen(
    (event) => _handleSocketEvent(controller, event),
  );

  if (controller.mode == TrackingMode.client) {
    await controller._websocketDatasource.connectForClient(userId);
    return;
  }
  if (!controller._isActive) {
    return;
  }
  if (controller.mode == TrackingMode.driver) {
    await controller._websocketDatasource.connectForDriver(userId);
  }
}

void _handleSocketEvent(
  TrackingController controller,
  TrackingSocketEvent event,
) {
  if (!controller._isActive) {
    return;
  }
  switch (event.type) {
    case TrackingSocketEventType.rideStatus:
      _handleRideStatusEvent(controller, event);
      return;
    case TrackingSocketEventType.driverLocation:
      _handleDriverLocationEvent(controller, event);
      return;
    case TrackingSocketEventType.rideMessage:
      _handleRideMessageEvent(controller, event);
      return;
    case TrackingSocketEventType.passengerReady:
      _handlePassengerReadyEvent(controller, event);
      return;
  }
}

void _handleRideStatusEvent(
  TrackingController controller,
  TrackingSocketEvent event,
) {
  final currentState = controller._currentStateOrNull;
  final ride = currentState?.ride;
  if (ride != null && ride.id == event.rideId) {
    controller._setStateIfAlive(currentState!.copyWith(
      ride: ride.copyWith(
        status: RideTrackingModel.fromRawStatus(event.status),
      ),
      toastMessage: trackingStatusToast(event.status),
    ));
    _recomputeDerivedState(controller);
    unawaited(_syncDriverForegroundLocation(controller));
  }
  unawaited(_refreshSnapshot(controller));
}

void _handleDriverLocationEvent(
  TrackingController controller,
  TrackingSocketEvent event,
) {
  final currentState = controller._currentStateOrNull;
  final position = event.position;
  if (currentState == null ||
      position == null ||
      !_isRelevantDriverLocation(controller, currentState, event)) {
    return;
  }
  final now = DateTime.now();
  if (!_isPlausibleDriverLocation(controller, currentState, position, now)) {
    return;
  }
  controller._lastDriverPositionAt = now;
  controller._setStateIfAlive(currentState.copyWith(
    driverHeadingDegrees: _headingBetween(
      currentState.driverPosition,
      position,
    ),
    driverPosition: position,
  ));
  _recomputeDerivedState(controller);
}

void _handlePassengerReadyEvent(
  TrackingController controller,
  TrackingSocketEvent event,
) {
  if (controller.mode != TrackingMode.driver) {
    return;
  }
  final currentState = controller._currentStateOrNull;
  final ride = currentState?.ride;
  if (currentState == null ||
      ride == null ||
      event.rideId == null ||
      event.rideId != ride.id) {
    return;
  }

  final passengerName = (event.passengerName ?? '').trim();
  if (passengerName.isEmpty) {
    return;
  }
  controller._setStateIfAlive(currentState.copyWith(
    ride: ride.copyWith(
      passengerReadyAt: event.timestamp ?? DateTime.now(),
    ),
  ));
  controller.showPassengerReadyBanner(
    '$passengerName est pret, descendez le chercher',
  );
  try {
    unawaited(HapticFeedback.lightImpact().catchError((_) => null));
  } catch (_) {
    // Some tests or platforms do not expose haptics; ignore gracefully.
  }
}

bool _isRelevantDriverLocation(
  TrackingController controller,
  TrackingState currentState,
  TrackingSocketEvent event,
) {
  final ride = currentState.ride;
  if (controller.mode != TrackingMode.client || ride == null) {
    return false;
  }
  return ride.driverId == null ||
      event.driverId == null ||
      ride.driverId == event.driverId;
}

bool _isPlausibleDriverLocation(
  TrackingController controller,
  TrackingState currentState,
  TrackingCoordinates position,
  DateTime now,
) {
  return isPlausibleTrackingUpdate(
    previous: currentState.driverPosition,
    next: position,
    elapsed: controller._lastDriverPositionAt == null
        ? null
        : now.difference(controller._lastDriverPositionAt!),
  );
}

void _startLocationTracking(TrackingController controller) {
  if (!controller._isActive) {
    return;
  }
  controller._locationSubscription?.cancel();
  controller._locationSubscription = controller._locationService
      .streamPosition(
    accuracy: LocationAccuracy.high,
    distanceFilter: 8,
  )
      .listen((result) {
    if (!controller._isActive) {
      return;
    }
    if (result case LocationSuccess<Position>(value: final position)) {
      _applyCurrentPosition(controller, position);
      return;
    }

    if (result case LocationError<Position>(failure: final failure)) {
      final currentState = controller._currentStateOrNull;
      if (currentState == null) {
        return;
      }
      controller._setStateIfAlive(
        currentState.copyWith(errorMessage: failure.message),
      );
    }
  });
}

void _applyCurrentPosition(
  TrackingController controller,
  Position position,
) {
  if (!controller._isActive) {
    return;
  }
  final currentState = controller._currentStateOrNull;
  if (currentState == null) {
    return;
  }
  final nextPoint = TrackingCoordinates(
    latitude: position.latitude,
    longitude: position.longitude,
  );
  final now = DateTime.now();
  if (!isPlausibleTrackingUpdate(
    previous: currentState.currentPosition,
    next: nextPoint,
    elapsed: controller._lastCurrentPositionAt == null
        ? null
        : now.difference(controller._lastCurrentPositionAt!),
  )) {
    return;
  }
  controller._lastCurrentPositionAt = now;
  controller._setStateIfAlive(currentState.copyWith(
    currentPosition: nextPoint,
    clearError: true,
  ));

  if (controller.mode == TrackingMode.driver) {
    final now = DateTime.now();
    if (controller._lastDriverPingAt == null ||
        now.difference(controller._lastDriverPingAt!) >=
            const Duration(seconds: 3)) {
      controller._lastDriverPingAt = now;
      controller._websocketDatasource.sendLocationUpdate(nextPoint);
    }
  }

  _recomputeDerivedState(controller);
}

Future<void> _syncDriverForegroundLocation(
  TrackingController controller,
) async {
  if (controller.mode != TrackingMode.driver) {
    return;
  }
  if (!_shouldRunDriverForegroundLocation(controller)) {
    await controller._foregroundLocationService.stopDriverTracking();
    return;
  }
  final result =
      await controller._foregroundLocationService.startDriverTracking();
  if (result == ForegroundLocationStartResult.started ||
      result == ForegroundLocationStartResult.unsupported ||
      !controller._isActive) {
    return;
  }
  final currentState = controller._currentStateOrNull;
  if (currentState == null) {
    return;
  }
  controller._setStateIfAlive(
    currentState.copyWith(errorMessage: _foregroundLocationPermissionMessage),
  );
}

Future<void> _recoverDriverForegroundLocation(
  TrackingController controller,
) async {
  if (controller.mode != TrackingMode.driver ||
      !_shouldRunDriverForegroundLocation(controller)) {
    return;
  }
  await controller._foregroundLocationService.recoverDriverTrackingIfNeeded();
}

Future<void> _stopDriverForegroundLocation(
  TrackingController controller,
) async {
  if (controller.mode != TrackingMode.driver) {
    return;
  }
  await controller._foregroundLocationService.stopDriverTracking();
}

bool _shouldRunDriverForegroundLocation(TrackingController controller) {
  final ride = controller._currentStateOrNull?.ride;
  return switch (ride?.status) {
    RideTrackingStatus.accepted ||
    RideTrackingStatus.arrived ||
    RideTrackingStatus.started =>
      true,
    _ => false,
  };
}
