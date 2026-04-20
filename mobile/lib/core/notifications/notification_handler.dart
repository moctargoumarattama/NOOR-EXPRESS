import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_router.dart';
import '../../app/app_routes.dart';

class NotificationHandler {
  void handleTap(Map<String, dynamic> data) {
    final route = _routeForPayload(data);
    final context = rootNavigatorKey.currentContext;
    if (route == null || context == null) {
      return;
    }

    context.push(route);
  }

  String? _routeForPayload(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    final rideId = int.tryParse(
      (data['ride_id'] ?? data['rideId'] ?? '').toString(),
    );

    if (rideId == null) {
      return null;
    }

    switch (type) {
      case 'new_offer':
        return AppRoutes.clientNegotiation(rideId);
      case 'offer_accepted':
        return AppRoutes.driverMapWithRide(rideId);
      case 'driver_en_route':
      case 'driver_arrived':
      case 'ride_started':
      case 'ride_completed':
        return AppRoutes.clientMapWithRide(rideId);
      case 'new_ride_request':
        return AppRoutes.driverOffer(rideId);
      default:
        return null;
    }
  }
}

final notificationHandlerProvider = Provider<NotificationHandler>((ref) {
  return NotificationHandler();
});
