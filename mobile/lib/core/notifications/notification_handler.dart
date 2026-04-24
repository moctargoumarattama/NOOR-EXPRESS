import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_router.dart';
import '../../app/app_routes.dart';

class NotificationHandler {
  void handleTap(Map<String, dynamic> data) {
    final route = notificationRouteForPayload(data);
    final context = rootNavigatorKey.currentContext;
    if (route == null || context == null) {
      return;
    }

    context.push(route);
  }
}

String? notificationRouteForPayload(Map<String, dynamic> data) {
  final type = data['type']?.toString();
  final targetRole = data['target_role']?.toString();
  final rideId = int.tryParse(
    (data['ride_id'] ?? data['ride_request_id'] ?? data['rideId'] ?? '')
        .toString(),
  );

  switch (type) {
    case 'offer_invalidated':
    case 'offer_rejected':
    case 'ride_cancelled':
      if (targetRole == 'driver') {
        return AppRoutes.driverHome;
      }
      if (targetRole == 'client') {
        return AppRoutes.clientHome;
      }
      return AppRoutes.driverHome;
    case 'ride_reopened':
      return rideId == null ? AppRoutes.clientHome : AppRoutes.clientNegotiation(rideId);
    case 'new_ride_request':
      return rideId == null ? AppRoutes.driverHome : AppRoutes.driverOffer(rideId);
    case 'new_offer':
      return rideId == null ? AppRoutes.clientHome : AppRoutes.clientNegotiation(rideId);
    case 'offer_accepted':
      return rideId == null ? AppRoutes.driverHome : AppRoutes.driverMapWithRide(rideId);
    case 'ride_accepted':
    case 'driver_en_route':
    case 'driver_arrived':
    case 'ride_started':
      return rideId == null ? AppRoutes.clientHome : AppRoutes.clientMapWithRide(rideId);
    case 'ride_completed':
      if (rideId == null) {
        return targetRole == 'driver' ? AppRoutes.driverHome : AppRoutes.clientHome;
      }
      if (targetRole == 'driver') {
        return AppRoutes.driverMapWithRide(rideId);
      }
      return AppRoutes.clientMapWithRide(rideId);
    default:
      return null;
  }
}

final notificationHandlerProvider = Provider<NotificationHandler>((ref) {
  return NotificationHandler();
});
