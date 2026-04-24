import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/ride_tracking/data/models/ride_tracking_model.dart';
import 'package:noor_express_mobile/features/ride_tracking/domain/entities/tracking_state.dart';
import 'package:noor_express_mobile/features/ride_tracking/presentation/controllers/tracking_controller_support.dart';

void main() {
  group('selectTrackingRide', () {
    test('prefers the backend active ride over a stale preferred local ride',
        () {
      final stalePreferredRide = _ride(
        id: 12,
        status: RideTrackingStatus.completed,
      );
      final activeRide = _ride(
        id: 44,
        status: RideTrackingStatus.accepted,
      );

      final selected = selectTrackingRide(
        TrackingMode.client,
        [stalePreferredRide],
        preferredRideId: stalePreferredRide.id,
        activeRide: activeRide,
      );

      expect(selected?.id, activeRide.id);
      expect(selected?.status, RideTrackingStatus.accepted);
    });
  });
}

RideTrackingModel _ride({
  required int id,
  required RideTrackingStatus status,
}) {
  return RideTrackingModel(
    id: id,
    clientId: 7,
    driverId: 9,
    pickupLocation: 'Pickup',
    dropoffLocation: 'Dropoff',
    estimatedPrice: 1500,
    createdAt: DateTime(2026, 4, 24),
    status: status,
  );
}
