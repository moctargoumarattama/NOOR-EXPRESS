import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/negotiation/data/models/ride_offer_model.dart';
import 'package:noor_express_mobile/features/negotiation/domain/entities/negotiation_state.dart';
import 'package:noor_express_mobile/features/negotiation/presentation/controllers/negotiation_resume_resolution.dart';

void main() {
  group('resolveNegotiationResume', () {
    test('navigates to tracking when backend says the scoped ride is accepted',
        () {
      final resolution = resolveNegotiationResume(
        mode: NegotiationMode.client,
        scopedRideId: 18,
        activeRide: _ride(rideId: 18, status: 'accepted'),
      );

      expect(resolution.action, NegotiationResumeAction.navigateToTracking);
      expect(resolution.targetRideId, 18);
    });

    test('closes to home when a driver offer is no longer active nor available',
        () {
      final resolution = resolveNegotiationResume(
        mode: NegotiationMode.driver,
        scopedRideId: 31,
      );

      expect(resolution.action, NegotiationResumeAction.closeToHome);
      expect(resolution.targetRideId, isNull);
    });
  });
}

NegotiationRideModel _ride({
  required int rideId,
  required String status,
}) {
  return NegotiationRideModel(
    rideId: rideId,
    pickup: 'Pickup',
    dropoff: 'Dropoff',
    clientPrice: 2200,
    status: status,
  );
}
