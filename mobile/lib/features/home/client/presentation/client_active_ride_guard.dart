import '../data/models/client_ride.dart';
import '../../../../shared/copy/ride_ui_copy.dart';

const clientAlreadyHasActiveRideErrorCode = 'client_already_has_active_ride';

bool shouldBlockClientRideCreation(ClientRide? activeRide) {
  if (activeRide == null) {
    return false;
  }

  switch (_normalizedStatus(activeRide.status)) {
    case 'pending':
    case 'offered':
    case 'accepted':
    case 'arrived':
    case 'started':
      return true;
    default:
      return false;
  }
}

bool shouldRecoverExistingRideFromCreateError(String? createErrorCode) {
  return createErrorCode?.trim().toLowerCase() ==
      clientAlreadyHasActiveRideErrorCode;
}

String activeRideResumeMessage(ClientRide ride) {
  switch (_normalizedStatus(ride.status)) {
    case 'pending':
    case 'offered':
      return RideUiCopy.resumeExistingRequest;
    default:
      return RideUiCopy.resumeExistingRide;
  }
}

String _normalizedStatus(String status) {
  return status.trim().toLowerCase();
}
