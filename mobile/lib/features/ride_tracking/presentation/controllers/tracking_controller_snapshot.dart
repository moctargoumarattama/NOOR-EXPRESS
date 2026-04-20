part of 'tracking_controller.dart';

Future<void> _refreshSnapshot(TrackingController controller) async {
  try {
    RideTrackingModel? ride;
    if (controller.preferredRideId == null) {
      final activeRideJson =
          await controller._remoteDatasource.fetchActiveRide();
      if (activeRideJson != null) {
        ride = RideTrackingModel.fromJson(activeRideJson);
      }
    }

    if (ride == null) {
      final ridesJson = controller.mode == TrackingMode.client
          ? await controller._remoteDatasource.fetchClientRides()
          : await controller._remoteDatasource.fetchDriverRides();
      final rides = ridesJson.map(RideTrackingModel.fromJson).toList();
      ride = selectTrackingRide(
        controller.mode,
        rides,
        preferredRideId: controller.preferredRideId,
      );
    }

    if (ride == null) {
      controller._currentState = controller._currentState.copyWith(
        clearRide: true,
        clearCounterpart: true,
        clearDriverPosition: true,
        clearEta: true,
      );
      return;
    }

    final counterpart = await _resolveCounterpart(controller, ride);
    controller._currentState = controller._currentState.copyWith(
      ride: ride,
      counterpart: counterpart,
    );
    _recomputeDerivedState(controller);
  } on TrackingRemoteFailure catch (error) {
    controller._currentState = controller._currentState.copyWith(
      errorMessage: error.message,
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
  final ride = controller._currentState.ride;
  if (ride == null) {
    return;
  }

  controller._currentState = controller._currentState.copyWith(
    isActionLoading: true,
    clearError: true,
  );
  try {
    final payload = await action(ride.id);
    controller._currentState = controller._currentState.copyWith(
      isActionLoading: false,
      ride: RideTrackingModel.fromJson(payload),
      toastMessage: successMessage,
    );
    _recomputeDerivedState(controller);
    await _refreshSnapshot(controller);
  } on TrackingRemoteFailure catch (error) {
    controller._currentState = controller._currentState.copyWith(
      isActionLoading: false,
      errorMessage: error.message,
    );
  }
}

void _recomputeDerivedState(TrackingController controller) {
  final ride = controller._currentState.ride;
  if (ride == null) {
    return;
  }

  final driverPosition = controller.mode == TrackingMode.driver
      ? controller._currentState.currentPosition
      : controller._currentState.driverPosition;
  final pickupPoint =
      ride.pickupPosition ?? controller._currentState.currentPosition;
  final target = switch (ride.status) {
    RideTrackingStatus.accepted => pickupPoint,
    RideTrackingStatus.arrived => pickupPoint,
    RideTrackingStatus.started => ride.dropoffPosition,
    _ => null,
  };

  controller._currentState = controller._currentState.copyWith(
    etaMinutes: estimateTrackingEta(
      rideStatus: ride.status,
      from: driverPosition,
      to: target,
    ),
  );
}

double? _headingBetween(
  TrackingCoordinates? previous,
  TrackingCoordinates? next,
) {
  return headingBetweenPoints(previous, next);
}
