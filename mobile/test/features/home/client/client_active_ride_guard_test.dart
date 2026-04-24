import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/home/client/data/models/client_ride.dart';
import 'package:noor_express_mobile/features/home/client/presentation/client_active_ride_guard.dart';
import 'package:noor_express_mobile/shared/copy/ride_ui_copy.dart';

void main() {
  group('shouldBlockClientRideCreation', () {
    test('blocks creation for a pending ride request', () {
      expect(
        shouldBlockClientRideCreation(_ride(status: 'pending')),
        isTrue,
      );
    });

    test('does not block creation for a completed ride', () {
      expect(
        shouldBlockClientRideCreation(_ride(status: 'completed')),
        isFalse,
      );
    });
  });

  group('activeRideResumeMessage', () {
    test('uses request wording for pending and offered rides', () {
      expect(
        activeRideResumeMessage(_ride(status: 'offered')),
        RideUiCopy.resumeExistingRequest,
      );
    });

    test('uses ride wording for accepted rides', () {
      expect(
        activeRideResumeMessage(_ride(status: 'accepted')),
        RideUiCopy.resumeExistingRide,
      );
    });
  });

  group('shouldRecoverExistingRideFromCreateError', () {
    test('matches the active ride backend conflict code', () {
      expect(
        shouldRecoverExistingRideFromCreateError(
          'client_already_has_active_ride',
        ),
        isTrue,
      );
    });

    test('ignores other backend conflict codes', () {
      expect(
        shouldRecoverExistingRideFromCreateError('ride_already_assigned'),
        isFalse,
      );
    });
  });
}

ClientRide _ride({required String status}) {
  return ClientRide(
    id: 1,
    pickupLocation: 'Plateau',
    dropoffLocation: 'Ocean',
    status: status,
    estimatedPrice: 1800,
    createdAt: DateTime(2026, 4, 24, 12),
  );
}
