import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/core/notifications/fcm_service.dart';

void main() {
  group('shouldPresentForegroundLocalNotification', () {
    test('suppresses ride and offer realtime pushes while the app is open', () {
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
}
