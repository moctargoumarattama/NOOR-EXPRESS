import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/ride_tracking/data/models/ride_tracking_model.dart';
import 'package:noor_express_mobile/features/ride_tracking/presentation/widgets/map_view.dart';

void main() {
  group('trackingRoutePolylinePoints', () {
    test('prefers reliable route points over the fallback straight segment', () {
      final points = trackingRoutePolylinePoints(
        routePoints: const [
          TrackingCoordinates(latitude: 13.51, longitude: 2.11),
          TrackingCoordinates(latitude: 13.52, longitude: 2.12),
          TrackingCoordinates(latitude: 13.53, longitude: 2.13),
        ],
        fallbackStart: const TrackingCoordinates(latitude: 13.40, longitude: 2.01),
        fallbackEnd: const TrackingCoordinates(latitude: 13.50, longitude: 2.10),
      );

      expect(points, hasLength(3));
      expect(points.first.latitude, 13.51);
      expect(points.last.longitude, 2.13);
    });

    test('falls back to a straight segment when route points are missing', () {
      final points = trackingRoutePolylinePoints(
        routePoints: const [],
        fallbackStart: const TrackingCoordinates(latitude: 13.40, longitude: 2.01),
        fallbackEnd: const TrackingCoordinates(latitude: 13.50, longitude: 2.10),
      );

      expect(points, hasLength(2));
      expect(points.first.latitude, 13.40);
      expect(points.last.longitude, 2.10);
    });
  });

  group('shouldRefitTrackingViewport', () {
    test('refits when the initial driver position becomes available', () {
      final shouldRefit = shouldRefitTrackingViewport(
        previousDriverPosition: null,
        nextDriverPosition: const TrackingCoordinates(
          latitude: 13.51,
          longitude: 2.11,
        ),
        previousCurrentPosition: const TrackingCoordinates(
          latitude: 13.52,
          longitude: 2.12,
        ),
        nextCurrentPosition: const TrackingCoordinates(
          latitude: 13.52,
          longitude: 2.12,
        ),
        previousPickupPosition: const TrackingCoordinates(
          latitude: 13.5,
          longitude: 2.1,
        ),
        nextPickupPosition: const TrackingCoordinates(
          latitude: 13.5,
          longitude: 2.1,
        ),
        previousDestinationPosition: const TrackingCoordinates(
          latitude: 13.49,
          longitude: 2.14,
        ),
        nextDestinationPosition: const TrackingCoordinates(
          latitude: 13.49,
          longitude: 2.14,
        ),
      );

      expect(shouldRefit, isTrue);
    });

    test('does not refit on every live driver movement once anchors are known', () {
      final shouldRefit = shouldRefitTrackingViewport(
        previousDriverPosition: const TrackingCoordinates(
          latitude: 13.51,
          longitude: 2.11,
        ),
        nextDriverPosition: const TrackingCoordinates(
          latitude: 13.5108,
          longitude: 2.1106,
        ),
        previousCurrentPosition: const TrackingCoordinates(
          latitude: 13.52,
          longitude: 2.12,
        ),
        nextCurrentPosition: const TrackingCoordinates(
          latitude: 13.52,
          longitude: 2.12,
        ),
        previousPickupPosition: const TrackingCoordinates(
          latitude: 13.5,
          longitude: 2.1,
        ),
        nextPickupPosition: const TrackingCoordinates(
          latitude: 13.5,
          longitude: 2.1,
        ),
        previousDestinationPosition: const TrackingCoordinates(
          latitude: 13.49,
          longitude: 2.14,
        ),
        nextDestinationPosition: const TrackingCoordinates(
          latitude: 13.49,
          longitude: 2.14,
        ),
      );

      expect(shouldRefit, isFalse);
    });

    test('refits when the destination anchor changes', () {
      final shouldRefit = shouldRefitTrackingViewport(
        previousDriverPosition: const TrackingCoordinates(
          latitude: 13.51,
          longitude: 2.11,
        ),
        nextDriverPosition: const TrackingCoordinates(
          latitude: 13.5108,
          longitude: 2.1106,
        ),
        previousCurrentPosition: const TrackingCoordinates(
          latitude: 13.52,
          longitude: 2.12,
        ),
        nextCurrentPosition: const TrackingCoordinates(
          latitude: 13.52,
          longitude: 2.12,
        ),
        previousPickupPosition: const TrackingCoordinates(
          latitude: 13.5,
          longitude: 2.1,
        ),
        nextPickupPosition: const TrackingCoordinates(
          latitude: 13.5,
          longitude: 2.1,
        ),
        previousDestinationPosition: const TrackingCoordinates(
          latitude: 13.49,
          longitude: 2.14,
        ),
        nextDestinationPosition: const TrackingCoordinates(
          latitude: 13.47,
          longitude: 2.18,
        ),
      );

      expect(shouldRefit, isTrue);
    });
  });

  group('resolveTrackingPulseAnchor', () {
    test('uses the pickup point while looking for a nearby driver', () {
      final target = resolveTrackingPulseAnchor(
        status: RideTrackingStatus.pending,
        driverPosition: null,
        pickupPosition: const TrackingCoordinates(
          latitude: 13.5,
          longitude: 2.1,
        ),
        currentPosition: const TrackingCoordinates(
          latitude: 13.52,
          longitude: 2.12,
        ),
      );

      expect(target, TrackingPulseAnchor.pickup);
    });

    test('uses the current position when pickup is still missing', () {
      final target = resolveTrackingPulseAnchor(
        status: RideTrackingStatus.pending,
        driverPosition: null,
        pickupPosition: null,
        currentPosition: const TrackingCoordinates(
          latitude: 13.52,
          longitude: 2.12,
        ),
      );

      expect(target, TrackingPulseAnchor.current);
    });

    test('uses the driver marker once the live car is known', () {
      final target = resolveTrackingPulseAnchor(
        status: RideTrackingStatus.accepted,
        driverPosition: const TrackingCoordinates(
          latitude: 13.51,
          longitude: 2.11,
        ),
        pickupPosition: const TrackingCoordinates(
          latitude: 13.5,
          longitude: 2.1,
        ),
        currentPosition: const TrackingCoordinates(
          latitude: 13.52,
          longitude: 2.12,
        ),
      );

      expect(target, TrackingPulseAnchor.driver);
    });

    test('stops the pulse when the ride is no longer active', () {
      final target = resolveTrackingPulseAnchor(
        status: RideTrackingStatus.completed,
        driverPosition: const TrackingCoordinates(
          latitude: 13.51,
          longitude: 2.11,
        ),
        pickupPosition: const TrackingCoordinates(
          latitude: 13.5,
          longitude: 2.1,
        ),
        currentPosition: const TrackingCoordinates(
          latitude: 13.52,
          longitude: 2.12,
        ),
      );

      expect(target, TrackingPulseAnchor.none);
    });
  });
}
