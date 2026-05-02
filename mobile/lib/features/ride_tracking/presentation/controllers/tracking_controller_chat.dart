part of 'tracking_controller.dart';

Future<void> _refreshChatUnreadCount(TrackingController controller) async {
  if (!controller._isActive) {
    return;
  }
  final ride = controller._currentStateOrNull?.ride;
  if (ride == null || !ride.canUseChat) {
    controller.syncUnreadChatCount(0);
    return;
  }

  try {
    final payload = await controller._remoteDatasource.fetchRideMessages(
      rideId: ride.id,
      limit: 1,
      offset: 0,
      markRead: false,
    );
    if (!controller._isActive) {
      return;
    }
    final unreadCount = (payload['unread_count'] as num?)?.toInt() ?? 0;
    controller.syncUnreadChatCount(unreadCount);
  } on TrackingRemoteFailure {
    if (!controller._isActive) {
      return;
    }
    controller.syncUnreadChatCount(0);
  }
}

void _handleRideMessageEvent(
  TrackingController controller,
  TrackingSocketEvent event,
) {
  if (!controller._isActive) {
    return;
  }
  final currentState = controller._currentStateOrNull;
  final message = event.message;
  final ride = currentState?.ride;
  final userId = controller.ref.read(sessionControllerProvider).userId;
  if (currentState == null ||
      ride == null ||
      userId == null ||
      message == null ||
      event.rideId != ride.id) {
    return;
  }
  if (message.isMine(userId) || currentState.isChatOpen) {
    return;
  }
  controller.syncUnreadChatCount(currentState.unreadChatCount + 1);
}
