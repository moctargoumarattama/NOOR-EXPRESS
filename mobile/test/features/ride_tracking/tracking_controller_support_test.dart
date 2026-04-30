import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/ride_tracking/data/models/ride_tracking_model.dart';
import 'package:noor_express_mobile/features/ride_tracking/domain/entities/tracking_state.dart';
import 'package:noor_express_mobile/features/ride_tracking/presentation/controllers/tracking_controller_support.dart';

void main() {
  group('TrackingCounterpartModel', () {
    test('uses the driver name and vehicle details when they are available',
        () {
      final counterpart = TrackingCounterpartModel.fromUserJson({
        'id': 9,
        'name': 'Amina Issoufou',
        'phone_number': '+22790000000',
        'vehicle_brand': 'Toyota',
        'vehicle_model': 'Corolla',
        'vehicle_color': 'blanche',
        'plate_number': 'NE-1234',
      });

      expect(counterpart.displayName, 'Amina Issoufou');
      expect(counterpart.phoneNumber, '+22790000000');
      expect(counterpart.vehicleLabel, 'Toyota - Corolla - blanche');
      expect(counterpart.plateNumber, 'NE-1234');
    });
  });

  group('estimateTrackingProgress', () {
    test('keeps straight-line distance but hides ETA until route is reliable',
        () {
      final progress = estimateTrackingProgress(
        rideStatus: RideTrackingStatus.accepted,
        from: const TrackingCoordinates(latitude: 13.51, longitude: 2.11),
        to: const TrackingCoordinates(latitude: 13.55, longitude: 2.16),
      );

      expect(progress, isNotNull);
      expect(progress!.distanceKm, greaterThan(0));
      expect(progress.etaMinutes, isNull);
      expect(progress.isEtaReliable, isFalse);
    });

    test('uses route metrics when a reliable route is available', () {
      final progress = estimateTrackingProgress(
        rideStatus: RideTrackingStatus.accepted,
        from: const TrackingCoordinates(latitude: 13.51, longitude: 2.11),
        to: const TrackingCoordinates(latitude: 13.55, longitude: 2.16),
        routeDistanceKm: 7.4,
        routeDurationMinutes: 18,
        isRouteReliable: true,
      );

      expect(progress?.distanceKm, 7.4);
      expect(progress?.etaMinutes, 18);
      expect(progress?.isEtaReliable, isTrue);
    });
  });

  group('isPlausibleTrackingUpdate', () {
    test('rejects impossible live location jumps', () {
      final accepted = isPlausibleTrackingUpdate(
        previous: const TrackingCoordinates(latitude: 13.51, longitude: 2.11),
        next: const TrackingCoordinates(latitude: 13.5104, longitude: 2.1104),
        elapsed: const Duration(seconds: 2),
      );
      final rejected = isPlausibleTrackingUpdate(
        previous: const TrackingCoordinates(latitude: 13.51, longitude: 2.11),
        next: const TrackingCoordinates(latitude: 13.80, longitude: 2.50),
        elapsed: const Duration(seconds: 2),
      );

      expect(accepted, isTrue);
      expect(rejected, isFalse);
    });
  });

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
