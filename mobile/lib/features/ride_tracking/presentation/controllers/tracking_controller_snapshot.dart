part of 'tracking_controller.dart';

Future<void> _refreshSnapshot(TrackingController controller) async {
  if (!controller._isActive) {
    return;
  }
  try {
    final activeRideJson = await controller._remoteDatasource.fetchActiveRide();
    if (!controller._isActive) {
      return;
    }
    final activeRide = activeRideJson == null
        ? null
        : RideTrackingModel.fromJson(activeRideJson);

    List<RideTrackingModel> rides = const [];
    if (activeRide == null) {
      final ridesJson = controller.mode == TrackingMode.client
          ? await controller._remoteDatasource.fetchClientRides()
          : await controller._remoteDatasource.fetchDriverRides();
      if (!controller._isActive) {
        return;
      }
      rides = ridesJson.map(RideTrackingModel.fromJson).toList();
    }

    final ride = selectTrackingRide(
      controller.mode,
      rides,
      preferredRideId: controller.preferredRideId,
      activeRide: activeRide,
    );

    if (ride == null) {
      final currentState = controller._currentStateOrNull;
      if (currentState == null) {
        return;
      }
      controller._setStateIfAlive(currentState.copyWith(
        clearRide: true,
        clearCounterpart: true,
        clearDriverPosition: true,
        clearEta: true,
      ));
      return;
    }

    final counterpart = await _resolveCounterpart(controller, ride);
    if (!controller._isActive) {
      return;
    }
    final currentState = controller._currentStateOrNull;
    if (currentState == null) {
      return;
    }
    controller._setStateIfAlive(currentState.copyWith(
      ride: ride,
      counterpart: counterpart,
    ));
    _recomputeDerivedState(controller);
  } on TrackingRemoteFailure catch (error) {
    final currentState = controller._currentStateOrNull;
    if (currentState == null) {
      return;
    }
    controller._setStateIfAlive(
      currentState.copyWith(errorMessage: error.message),
    );
  }
}

Future<TrackingCounterpartModel?> _resolveCounterpart(
  TrackingController controller,
  RideTrackingModel ride,
) async {
  final counterpartId =
      controller.mode == TrackingMode.client ? ride.driverId : ride.clientId;
  if (counterpartId == null) {
    return null;
  }

  final userJson = await controller._remoteDatasource.fetchUser(counterpartId);
  final rating = controller.mode == TrackingMode.client && ride.driverId != null
      ? await controller._remoteDatasource.fetchDriverRating(ride.driverId!)
      : null;
  return TrackingCounterpartModel.fromUserJson(userJson, rating: rating);
}

Future<void> _runRideAction(
  TrackingController controller, {
  required Future<Map<String, dynamic>> Function(int rideId) action,
  required String successMessage,
}) async {
  if (!controller._isActive) {
    return;
  }
  final currentState = controller._currentStateOrNull;
  final ride = currentState?.ride;
  if (ride == null) {
    return;
  }

  controller._setStateIfAlive(currentState!.copyWith(
    isActionLoading: true,
    clearError: true,
  ));
  try {
    final payload = await action(ride.id);
    if (!controller._isActive) {
      return;
    }
    final nextState = controller._currentStateOrNull;
    if (nextState == null) {
      return;
    }
    controller._setStateIfAlive(nextState.copyWith(
      isActionLoading: false,
      ride: RideTrackingModel.fromJson(payload),
      toastMessage: successMessage,
    ));
    _recomputeDerivedState(controller);
    await _refreshSnapshot(controller);
  } on TrackingRemoteFailure catch (error) {
    final nextState = controller._currentStateOrNull;
    if (nextState == null) {
      return;
    }
    controller._setStateIfAlive(nextState.copyWith(
      isActionLoading: false,
      errorMessage: error.message,
    ));
  }
}

void _recomputeDerivedState(TrackingController controller) {
  if (!controller._isActive) {
    return;
  }
  final currentState = controller._currentStateOrNull;
  final ride = currentState?.ride;
  if (ride == null) {
    return;
  }

  final driverPosition = controller.mode == TrackingMode.driver
      ? currentState!.currentPosition
      : currentState!.driverPosition;
  final pickupPoint = ride.pickupPosition ?? currentState.currentPosition;
  final target = switch (ride.status) {
    RideTrackingStatus.accepted => pickupPoint,
    RideTrackingStatus.arrived => pickupPoint,
    RideTrackingStatus.started => ride.dropoffPosition,
    _ => null,
  };

  controller._setStateIfAlive(currentState.copyWith(
    etaMinutes: estimateTrackingEta(
      rideStatus: ride.status,
      from: driverPosition,
      to: target,
    ),
  ));
}

double? _headingBetween(
  TrackingCoordinates? previous,
  TrackingCoordinates? next,
) {
  return headingBetweenPoints(previous, next);
}
