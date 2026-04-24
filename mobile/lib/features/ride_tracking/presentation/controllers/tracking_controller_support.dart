import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import '../../data/models/ride_tracking_model.dart';
import '../../domain/entities/tracking_state.dart';

RideTrackingModel? selectTrackingRide(
  TrackingMode mode,
  List<RideTrackingModel> rides, {
  int? preferredRideId,
  RideTrackingModel? activeRide,
}) {
  if (activeRide != null) {
    return activeRide;
  }

  if (preferredRideId != null) {
    for (final ride in rides) {
      if (ride.id == preferredRideId) {
        return ride;
      }
    }
  }

  final priority = mode == TrackingMode.client
      ? const [
          RideTrackingStatus.pending,
          RideTrackingStatus.offered,
          RideTrackingStatus.accepted,
          RideTrackingStatus.arrived,
          RideTrackingStatus.started,
          RideTrackingStatus.completed,
        ]
      : const [
          RideTrackingStatus.accepted,
          RideTrackingStatus.arrived,
          RideTrackingStatus.started,
          RideTrackingStatus.completed,
        ];

  for (final status in priority) {
    for (final ride in rides) {
      if (ride.status == status) {
        return ride;
      }
    }
  }

  return rides.isEmpty ? null : rides.first;
}

int? estimateTrackingEta({
  required RideTrackingStatus rideStatus,
  required TrackingCoordinates? from,
  required TrackingCoordinates? to,
}) {
  if (from == null || to == null) {
    return null;
  }

  final distanceKm = Geolocator.distanceBetween(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      ) /
      1000;
  final averageSpeedKmh =
      rideStatus == RideTrackingStatus.started ? 28.0 : 22.0;
  return math.max(1, ((distanceKm / averageSpeedKmh) * 60).round());
}

double? headingBetweenPoints(
  TrackingCoordinates? previous,
  TrackingCoordinates? next,
) {
  if (previous == null || next == null) {
    return null;
  }

  final previousLatitude = previous.latitude * math.pi / 180;
  final nextLatitude = next.latitude * math.pi / 180;
  final deltaLongitude = (next.longitude - previous.longitude) * math.pi / 180;
  final y = math.sin(deltaLongitude) * math.cos(nextLatitude);
  final x = math.cos(previousLatitude) * math.sin(nextLatitude) -
      math.sin(previousLatitude) *
          math.cos(nextLatitude) *
          math.cos(deltaLongitude);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

String trackingStatusToast(String? status) {
  switch (status) {
    case 'offered':
      return 'Des offres sont arrivees.';
    case 'accepted':
      return 'Votre chauffeur a accepte la course.';
    case 'arrived':
      return 'Votre chauffeur est arrive.';
    case 'started':
      return 'La course a commence.';
    case 'completed':
      return 'La course est terminee.';
    case 'cancelled':
      return 'La course a ete annulee.';
    case 'pending':
      return 'La course redevient negotiable.';
    default:
      return 'Statut de course mis a jour.';
  }
}
