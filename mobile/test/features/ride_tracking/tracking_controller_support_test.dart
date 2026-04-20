import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/ride_tracking/data/models/ride_tracking_model.dart';
import 'package:noor_express_mobile/features/ride_tracking/domain/entities/tracking_state.dart';
import 'package:noor_express_mobile/features/ride_tracking/presentation/controllers/tracking_controller_support.dart';

void main() {
  RideTrackingModel buildRide({
    required int id,
    required RideTrackingStatus status,
  }) {
    return RideTrackingModel(
      id: id,
      clientId: 1,
      driverId: 2,
      pickupLocation: 'Plateau',
      dropoffLocation: 'Gamkalley',
      estimatedPrice: 2000,
      createdAt: DateTime(2026, 4, 18),
      status: status,
    );
  }

  test('selectTrackingRide prioritizes active client ride', () {
    final rides = [
      buildRide(id: 1, status: RideTrackingStatus.completed),
      buildRide(id: 2, status: RideTrackingStatus.accepted),
      buildRide(id: 3, status: RideTrackingStatus.pending),
    ];

    final selected = selectTrackingRide(TrackingMode.client, rides);

    expect(selected?.id, 3);
  });

  test('estimateTrackingEta returns a positive integer', () {
    final eta = estimateTrackingEta(
      rideStatus: RideTrackingStatus.accepted,
      from: const TrackingCoordinates(latitude: 13.511, longitude: 2.120),
      to: const TrackingCoordinates(latitude: 13.514, longitude: 2.132),
    );

    expect(eta, isNotNull);
    expect(eta, greaterThanOrEqualTo(1));
  });

  test('headingBetweenPoints returns null when point missing', () {
    expect(
      headingBetweenPoints(
        null,
        const TrackingCoordinates(latitude: 13.5, longitude: 2.1),
      ),
      isNull,
    );
  });
}
