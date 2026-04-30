import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/core/notifications/fcm_service.dart';

void main() {
  group('shouldPresentForegroundLocalNotification', () {
    test('suppresses OS local notifications for critical foreground pushes', () {
      expect(shouldPresentForegroundLocalNotification('new_offer'), isFalse);
      expect(shouldPresentForegroundLocalNotification('ride_accepted'), isFalse);
      expect(
        shouldPresentForegroundLocalNotification('ride_completed'),
        isFalse,
      );
      expect(
        shouldPresentForegroundLocalNotification('new_ride_request'),
        isFalse,
      );
    });

    test('keeps unknown notification types eligible for a local alert', () {
      expect(shouldPresentForegroundLocalNotification('marketing'), isTrue);
      expect(shouldPresentForegroundLocalNotification(null), isTrue);
    });
  });

  group('shouldPresentForegroundInAppNotification', () {
    test('shows in-app notifications for critical ride and offer events', () {
      for (final type in [
        'new_offer',
        'offer_accepted',
        'ride_accepted',
        'driver_arrived',
        'ride_started',
        'ride_completed',
        'ride_cancelled',
      ]) {
        expect(
          shouldPresentForegroundInAppNotification(type),
          isTrue,
          reason: type,
        );
      }
    });

    test('does not show in-app notifications for unknown foreground pushes',
        () {
      expect(shouldPresentForegroundInAppNotification('marketing'), isFalse);
      expect(shouldPresentForegroundInAppNotification(null), isFalse);
    });
  });

  group('isUsableFcmToken', () {
    test('accepts only non-empty production-length FCM tokens', () {
      expect(isUsableFcmToken('short-token'), isFalse);
      expect(isUsableFcmToken('   '), isFalse);
      expect(isUsableFcmToken('aaaaaaaaaaaaaaaaaaaa'), isTrue);
    });
  });
}
