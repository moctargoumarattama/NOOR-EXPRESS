import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/ride_tracking/data/models/ride_tracking_model.dart';
import 'package:noor_express_mobile/features/ride_tracking/presentation/widgets/map_view.dart';

void main() {
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
}
