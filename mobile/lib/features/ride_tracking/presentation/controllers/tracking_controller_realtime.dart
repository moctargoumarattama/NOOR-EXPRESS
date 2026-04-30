part of 'tracking_controller.dart';

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
      }
      unawaited(_refreshSnapshot(controller));
      return;
    case TrackingSocketEventType.driverLocation:
      final currentState = controller._currentStateOrNull;
      if (currentState == null) {
        return;
      }
      final ride = currentState.ride;
      final position = event.position;
      if (controller.mode != TrackingMode.client ||
          position == null ||
          ride == null ||
          (ride.driverId != null &&
              event.driverId != null &&
              ride.driverId != event.driverId)) {
        return;
      }

      final now = DateTime.now();
      if (!isPlausibleTrackingUpdate(
        previous: currentState.driverPosition,
        next: position,
        elapsed: controller._lastDriverPositionAt == null
            ? null
            : now.difference(controller._lastDriverPositionAt!),
      )) {
        return;
      }
      controller._lastDriverPositionAt = now;
      controller._setStateIfAlive(currentState.copyWith(
        driverHeadingDegrees:
            _headingBetween(currentState.driverPosition, position),
        driverPosition: position,
      ));
      _recomputeDerivedState(controller);
      return;
  }
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
