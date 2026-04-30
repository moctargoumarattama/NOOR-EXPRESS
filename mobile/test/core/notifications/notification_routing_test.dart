import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/app/app_routes.dart';
import 'package:noor_express_mobile/core/notifications/local_notification_service.dart';
import 'package:noor_express_mobile/core/notifications/notification_handler.dart';

void main() {
  group('notificationRouteForPayload', () {
    test('routes all critical client events to client home for backend resync',
        () {
      for (final type in [
        'new_offer',
        'ride_accepted',
        'driver_arrived',
        'ride_started',
        'ride_completed',
        'ride_cancelled',
        'ride_reopened',
      ]) {
        expect(
          notificationRouteForPayload({
            'type': type,
            'ride_id': 18,
            'target_role': 'client',
          }),
          AppRoutes.clientHome,
          reason: type,
        );
      }
    });

    test('routes all critical driver events to driver home for backend resync',
        () {
      for (final type in [
        'offer_accepted',
        'offer_invalidated',
        'offer_rejected',
        'ride_completed',
        'ride_cancelled',
        'new_ride_request',
      ]) {
        expect(
          notificationRouteForPayload({
            'type': type,
            'ride_id': 21,
            'target_role': 'driver',
          }),
          AppRoutes.driverHome,
          reason: type,
        );
      }
    });
  });

  group('NotificationHandler', () {
    testWidgets('opens home and resyncs backend truth after a notification tap',
        (tester) async {
      BuildContext? capturedContext;
      String? openedRoute;
      Map<String, dynamic>? resyncedPayload;
      final payload = {
        'type': 'ride_completed',
        'ride_id': 21,
        'target_role': 'driver',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final handler = NotificationHandler(
        contextReader: () => capturedContext,
        navigator: (context, route) => openedRoute = route,
        backendResync: (context, data) async {
          resyncedPayload = data;
        },
      );

      handler.handleTap(payload);
      await tester.pump();

      expect(openedRoute, AppRoutes.driverHome);
      expect(resyncedPayload, payload);
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
