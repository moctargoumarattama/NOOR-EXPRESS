part of 'tracking_controller.dart';

Future<void> _bindRealtime(TrackingController controller) async {
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
      controller._currentState = controller._currentState.copyWith(
        connectionState: connectionState,
      );
    },
  );
  controller._eventSubscription = controller._websocketDatasource.events.listen(
    (event) => _handleSocketEvent(controller, event),
  );

  if (controller.mode == TrackingMode.client) {
    await controller._websocketDatasource.connectForClient(userId);
  } else {
    await controller._websocketDatasource.connectForDriver(userId);
  }
}

void _handleSocketEvent(
  TrackingController controller,
  TrackingSocketEvent event,
) {
  switch (event.type) {
    case TrackingSocketEventType.rideStatus:
      final ride = controller._currentState.ride;
      if (ride != null && ride.id == event.rideId) {
        controller._currentState = controller._currentState.copyWith(
          ride: ride.copyWith(
            status: RideTrackingModel.fromRawStatus(event.status),
          ),
          toastMessage: trackingStatusToast(event.status),
        );
        _recomputeDerivedState(controller);
      }
      unawaited(_refreshSnapshot(controller));
      return;
    case TrackingSocketEventType.driverLocation:
      final ride = controller._currentState.ride;
      if (controller.mode != TrackingMode.client ||
          event.position == null ||
          ride == null ||
          (ride.driverId != null &&
              event.driverId != null &&
              ride.driverId != event.driverId)) {
        return;
      }

      controller._currentState = controller._currentState.copyWith(
        driverHeadingDegrees: _headingBetween(
            controller._currentState.driverPosition, event.position),
        driverPosition: event.position,
      );
      _recomputeDerivedState(controller);
      return;
  }
}

void _startLocationTracking(TrackingController controller) {
  controller._locationSubscription?.cancel();
  controller._locationSubscription = controller._locationService
      .streamPosition(
    accuracy: LocationAccuracy.high,
    distanceFilter: 8,
    timeout: const Duration(seconds: 20),
  )
      .listen((result) {
    if (result case LocationSuccess<Position>(value: final position)) {
      _applyCurrentPosition(controller, position);
      return;
    }

    if (result case LocationError<Position>(failure: final failure)) {
      controller._currentState = controller._currentState.copyWith(
        errorMessage: failure.message,
      );
    }
  });
}

void _applyCurrentPosition(
  TrackingController controller,
  Position position,
) {
  final nextPoint = TrackingCoordinates(
    latitude: position.latitude,
    longitude: position.longitude,
  );
  controller._currentState = controller._currentState.copyWith(
    currentPosition: nextPoint,
    clearError: true,
  );

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
