import '../../app/app_routes.dart';

const Set<String> criticalNotificationTypes = {
  'new_offer',
  'offer_accepted',
  'offer_rejected',
  'offer_invalidated',
  'new_ride_request',
  'ride_accepted',
  'driver_en_route',
  'driver_arrived',
  'ride_started',
  'ride_completed',
  'ride_cancelled',
  'ride_reopened',
};

bool isCriticalNotificationType(String? type) {
  final normalized = type?.trim();
  return normalized != null && criticalNotificationTypes.contains(normalized);
}

String? notificationHomeRouteForPayload(Map<String, dynamic> data) {
  final type = data['type']?.toString();
  if (!isCriticalNotificationType(type)) {
    return null;
  }

  final targetRole = notificationTargetRoleForPayload(data);
  if (targetRole == 'driver') {
    return AppRoutes.driverHome;
  }
  if (targetRole == 'client') {
    return AppRoutes.clientHome;
  }

  return switch (type) {
    'offer_accepted' ||
    'offer_rejected' ||
    'offer_invalidated' ||
    'new_ride_request' =>
      AppRoutes.driverHome,
    _ => AppRoutes.clientHome,
  };
}

String? notificationTargetRoleForPayload(Map<String, dynamic> data) {
  final targetRole = data['target_role']?.toString().trim();
  if (targetRole == 'client' || targetRole == 'driver') {
    return targetRole;
  }

  return switch (data['type']?.toString()) {
    'offer_accepted' ||
    'offer_rejected' ||
    'offer_invalidated' ||
    'new_ride_request' =>
      'driver',
    'new_offer' ||
    'ride_accepted' ||
    'driver_en_route' ||
    'driver_arrived' ||
    'ride_started' ||
    'ride_reopened' =>
      'client',
    _ => null,
  };
}

String notificationInAppMessageForPayload(
  Map<String, dynamic> data, {
  String? title,
  String? body,
}) {
  final cleanedBody = body?.trim();
  if (cleanedBody != null && cleanedBody.isNotEmpty) {
    return cleanedBody;
  }

  return switch (data['type']?.toString()) {
    'new_offer' => 'Nouvelle offre recue.',
    'offer_accepted' => 'Votre offre a ete acceptee.',
    'offer_rejected' => 'Votre offre a ete refusee.',
    'offer_invalidated' => 'Cette offre n est plus disponible.',
    'new_ride_request' => 'Nouvelle course disponible.',
    'ride_accepted' => 'Chauffeur assigne.',
    'driver_arrived' => 'Le chauffeur est arrive.',
    'ride_started' => 'La course a demarre.',
    'ride_completed' => 'La course est terminee.',
    'ride_cancelled' => 'La course a ete annulee.',
    'ride_reopened' => 'La course est revenue en recherche.',
    _ => title?.trim().isNotEmpty == true ? title!.trim() : 'Noor Express',
  };
}
