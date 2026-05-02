part of 'tracking_controller.dart';

Future<void> _refreshSnapshot(
  TrackingController controller, {
  bool requireActiveRide = false,
}) async {
  if (!controller._isActive) {
    return;
  }
  try {
    final ride = await _loadTrackingRide(
      controller,
      requireActiveRide: requireActiveRide,
    );
    if (!controller._isActive) {
      return;
    }
    if (ride == null) {
      await _clearTrackingRide(controller);
      return;
    }

    await _applyTrackingRide(controller, ride);
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

Future<RideTrackingModel?> _loadTrackingRide(
  TrackingController controller, {
  required bool requireActiveRide,
}) async {
  final activeRideJson = await controller._remoteDatasource.fetchActiveRide();
  if (!controller._isActive) {
    return null;
  }
  final activeRide = activeRideJson == null
      ? null
      : RideTrackingModel.fromJson(activeRideJson);
  final rides = await _loadCandidateRides(
    controller,
    hasActiveRide: activeRide != null,
    requireActiveRide: requireActiveRide,
  );
  if (!controller._isActive) {
    return null;
  }
  return selectTrackingRide(
    controller.mode,
    rides,
    preferredRideId: controller.preferredRideId,
    activeRide: activeRide,
  );
}

Future<List<RideTrackingModel>> _loadCandidateRides(
  TrackingController controller, {
  required bool hasActiveRide,
  required bool requireActiveRide,
}) async {
  if (hasActiveRide || requireActiveRide) {
    return const [];
  }
  final ridesJson = controller.mode == TrackingMode.client
      ? await controller._remoteDatasource.fetchClientRides()
      : await controller._remoteDatasource.fetchDriverRides();
  return ridesJson.map(RideTrackingModel.fromJson).toList();
}

Future<void> _clearTrackingRide(TrackingController controller) async {
  final currentState = controller._currentStateOrNull;
  if (currentState == null) {
    return;
  }
  controller._setStateIfAlive(currentState.copyWith(
    clearRide: true,
    clearCounterpart: true,
    clearDriverPosition: true,
    clearDistanceRemaining: true,
    clearEta: true,
    clearRoute: true,
    unreadChatCount: 0,
    isChatOpen: false,
  ));
  await _syncDriverForegroundLocation(controller);
}

Future<void> _applyTrackingRide(
  TrackingController controller,
  RideTrackingModel ride,
) async {
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
  await _refreshChatUnreadCount(controller);
  await _syncDriverForegroundLocation(controller);
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
  final progress = estimateTrackingProgress(
    rideStatus: ride.status,
    from: driverPosition,
    to: target,
  );

  controller._setStateIfAlive(currentState.copyWith(
    etaMinutes: progress?.etaMinutes,
    distanceRemainingKm: progress?.distanceKm,
    isEtaReliable: progress?.isEtaReliable ?? false,
    clearEta: progress?.etaMinutes == null,
    clearDistanceRemaining: progress == null,
    clearRoute: target == null || driverPosition == null,
  ));
  if (driverPosition != null && target != null) {
    unawaited(_refreshReliableRoute(controller, ride, driverPosition, target));
  }
}

double? _headingBetween(
  TrackingCoordinates? previous,
  TrackingCoordinates? next,
) {
  return headingBetweenPoints(previous, next);
}

Future<void> _refreshReliableRoute(
  TrackingController controller,
  RideTrackingModel ride,
  TrackingCoordinates origin,
  TrackingCoordinates target,
) async {
  if (!controller._isActive || controller._isRouteRefreshInFlight) {
    return;
  }
  final now = DateTime.now();
  if (!_shouldRefreshTrackingRoute(
    lastRefreshAt: controller._lastRouteRefreshAt,
    lastOrigin: controller._lastRouteOrigin,
    lastTarget: controller._lastRouteTarget,
    nextOrigin: origin,
    nextTarget: target,
    now: now,
  )) {
    return;
  }

  controller._isRouteRefreshInFlight = true;
  controller._lastRouteRefreshAt = now;
  controller._lastRouteOrigin = origin;
  controller._lastRouteTarget = target;

  try {
    final route = await controller._routingService.getRoute(
      LatLng(origin.latitude, origin.longitude),
      LatLng(target.latitude, target.longitude),
    );
    if (!controller._isActive || !route.hasReliableMetrics) {
      return;
    }
    final currentState = controller._currentStateOrNull;
    if (currentState?.ride?.id != ride.id) {
      return;
    }

    final progress = estimateTrackingProgress(
      rideStatus: ride.status,
      from: origin,
      to: target,
      routeDistanceKm: route.distanceKm,
      routeDurationMinutes: route.durationMinutes,
      isRouteReliable: route.hasReliableMetrics,
    );
    if (progress == null) {
      return;
    }

    controller._setStateIfAlive(currentState!.copyWith(
      etaMinutes: progress.etaMinutes,
      distanceRemainingKm: progress.distanceKm,
      isEtaReliable: progress.isEtaReliable,
      routePoints: _routeToTrackingCoordinates(route),
    ));
  } finally {
    controller._isRouteRefreshInFlight = false;
  }
}

bool _shouldRefreshTrackingRoute({
  required DateTime? lastRefreshAt,
  required TrackingCoordinates? lastOrigin,
  required TrackingCoordinates? lastTarget,
  required TrackingCoordinates nextOrigin,
  required TrackingCoordinates nextTarget,
  required DateTime now,
}) {
  if (lastRefreshAt != null &&
      now.difference(lastRefreshAt) < const Duration(seconds: 8)) {
    return false;
  }
  if (lastOrigin == null || lastTarget == null) {
    return true;
  }

  final originMovedMeters = Geolocator.distanceBetween(
    lastOrigin.latitude,
    lastOrigin.longitude,
    nextOrigin.latitude,
    nextOrigin.longitude,
  );
  final targetMovedMeters = Geolocator.distanceBetween(
    lastTarget.latitude,
    lastTarget.longitude,
    nextTarget.latitude,
    nextTarget.longitude,
  );
  return originMovedMeters >= 80 || targetMovedMeters >= 25;
}

List<TrackingCoordinates> _routeToTrackingCoordinates(RouteResult route) {
  return route.polylinePoints
      .map(
        (point) => TrackingCoordinates(
          latitude: point.latitude,
          longitude: point.longitude,
        ),
      )
      .toList(growable: false);
}
