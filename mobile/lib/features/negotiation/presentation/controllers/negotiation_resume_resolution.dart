import '../../data/models/ride_offer_model.dart';
import '../../domain/entities/negotiation_state.dart';

enum NegotiationResumeAction {
  stayOnNegotiation,
  navigateToTracking,
  closeToHome,
}

class NegotiationResumeResolution {
  const NegotiationResumeResolution({
    required this.action,
    this.ride,
    this.targetRideId,
    this.shouldReloadOffers = false,
  });

  final NegotiationResumeAction action;
  final NegotiationRideModel? ride;
  final int? targetRideId;
  final bool shouldReloadOffers;
}

NegotiationResumeResolution resolveNegotiationResume({
  required NegotiationMode mode,
  required int scopedRideId,
  NegotiationRideModel? activeRide,
  NegotiationRideModel? scopedRide,
}) {
  if (activeRide != null) {
    if (activeRide.rideId != scopedRideId) {
      if (_shouldNavigateToTracking(activeRide.status)) {
        return NegotiationResumeResolution(
          action: NegotiationResumeAction.navigateToTracking,
          ride: activeRide,
          targetRideId: activeRide.rideId,
        );
      }
      return const NegotiationResumeResolution(
        action: NegotiationResumeAction.closeToHome,
      );
    }

    return _resolveScopedRide(mode, activeRide);
  }

  if (scopedRide != null) {
    return _resolveScopedRide(mode, scopedRide);
  }

  return const NegotiationResumeResolution(
    action: NegotiationResumeAction.closeToHome,
  );
}

NegotiationResumeResolution _resolveScopedRide(
  NegotiationMode mode,
  NegotiationRideModel ride,
) {
  if (_shouldNavigateToTracking(ride.status)) {
    return NegotiationResumeResolution(
      action: NegotiationResumeAction.navigateToTracking,
      ride: ride,
      targetRideId: ride.rideId,
    );
  }

  if (_shouldStayOnNegotiation(ride.status)) {
    return NegotiationResumeResolution(
      action: NegotiationResumeAction.stayOnNegotiation,
      ride: ride,
      shouldReloadOffers: mode == NegotiationMode.client,
    );
  }

  return const NegotiationResumeResolution(
    action: NegotiationResumeAction.closeToHome,
  );
}

bool _shouldNavigateToTracking(String status) {
  return status == 'accepted' || status == 'arrived' || status == 'started';
}

bool _shouldStayOnNegotiation(String status) {
  return status == 'pending' || status == 'offered';
}
