import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/app/app_routes.dart';
import 'package:noor_express_mobile/core/notifications/local_notification_service.dart';
import 'package:noor_express_mobile/core/notifications/notification_handler.dart';

void main() {
  group('notificationRouteForPayload', () {
    test('routes accepted client rides to tracking', () {
      expect(
        notificationRouteForPayload({'type': 'ride_accepted', 'ride_id': 18}),
        AppRoutes.clientMapWithRide(18),
      );
    });

    test('routes reopened client rides back to negotiation', () {
      expect(
        notificationRouteForPayload({'type': 'ride_reopened', 'ride_id': 11}),
        AppRoutes.clientNegotiation(11),
      );
    });

    test('routes invalidated driver-side events to driver home', () {
      expect(
        notificationRouteForPayload(
          {'type': 'offer_invalidated', 'ride_id': 7, 'target_role': 'driver'},
        ),
        AppRoutes.driverHome,
      );
      expect(
        notificationRouteForPayload(
          {'type': 'offer_rejected', 'ride_id': 7, 'target_role': 'driver'},
        ),
        AppRoutes.driverHome,
      );
      expect(
        notificationRouteForPayload(
          {'type': 'ride_cancelled', 'ride_id': 7, 'target_role': 'driver'},
        ),
        AppRoutes.driverHome,
      );
    });

    test('routes completed driver rides back to the driver tracking flow', () {
      expect(
        notificationRouteForPayload(
          {'type': 'ride_completed', 'ride_id': 21, 'target_role': 'driver'},
        ),
        AppRoutes.driverMapWithRide(21),
      );
    });
  });

  group('notificationChannelIdForType', () {
    test('classifies ride lifecycle notifications into the rides channel', () {
      expect(notificationChannelIdForType('ride_accepted'), 'rides');
      expect(notificationChannelIdForType('driver_arrived'), 'rides');
      expect(notificationChannelIdForType('ride_completed'), 'rides');
      expect(notificationChannelIdForType('ride_reopened'), 'rides');
    });

    test('classifies negotiation notifications into the offers channel', () {
      expect(notificationChannelIdForType('new_offer'), 'offers');
      expect(notificationChannelIdForType('offer_invalidated'), 'offers');
      expect(notificationChannelIdForType('offer_rejected'), 'offers');
    });
  });
}
