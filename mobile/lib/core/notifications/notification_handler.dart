import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_router.dart';
import '../../features/home/client/presentation/controllers/client_home_controller.dart';
import '../../features/home/driver/presentation/controllers/ride_driver_controller.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'notification_event.dart';

typedef NotificationNavigator = void Function(
  BuildContext context,
  String route,
);
typedef NotificationBackendResync = Future<void> Function(
  BuildContext context,
  Map<String, dynamic> data,
);

class NotificationHandler {
  NotificationHandler({
    BuildContext? Function()? contextReader,
    NotificationNavigator? navigator,
    NotificationBackendResync? backendResync,
    Duration retryDelay = const Duration(milliseconds: 250),
    int maxOpenAttempts = 24,
  })  : _contextReader = contextReader,
        _navigator = navigator,
        _backendResync = backendResync,
        _retryDelay = retryDelay,
        _maxOpenAttempts = maxOpenAttempts;

  final BuildContext? Function()? _contextReader;
  final NotificationNavigator? _navigator;
  final NotificationBackendResync? _backendResync;
  final Duration _retryDelay;
  final int _maxOpenAttempts;

  void handleTap(Map<String, dynamic> data) {
    final route = notificationRouteForPayload(data);
    if (route == null) {
      return;
    }
    _openWhenReady(data, route, attempt: 0);
  }

  void showInApp(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) {
    final context = _readContext();
    if (context == null) {
      return;
    }

    AppSnackbar.show(
      context,
      message: notificationInAppMessageForPayload(
        data,
        title: title,
        body: body,
      ),
      tone: _snackbarToneForPayload(data),
    );
    unawaited(_resyncBackendTruth(context, data));
  }

  void _openWhenReady(
    Map<String, dynamic> data,
    String route, {
    required int attempt,
  }) {
    final context = rootNavigatorKey.currentContext;
    final resolvedContext = _readContext() ?? context;
    if (resolvedContext == null) {
      if (attempt >= _maxOpenAttempts) {
        return;
      }
      Future<void>.delayed(_retryDelay, () {
        _openWhenReady(data, route, attempt: attempt + 1);
      });
      return;
    }

    (_navigator ?? _goToRoute)(resolvedContext, route);
    unawaited((_backendResync ?? _resyncBackendTruth)(resolvedContext, data));
  }

  BuildContext? _readContext() {
    return _contextReader?.call() ?? rootNavigatorKey.currentContext;
  }

  void _goToRoute(BuildContext context, String route) {
    context.go(route);
  }

  Future<void> _resyncBackendTruth(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    ProviderContainer container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } catch (_) {
      return;
    }

    final route = notificationRouteForPayload(data);
    final targetRole = notificationTargetRoleForPayload(data);
    if (targetRole == 'driver' || route == '/driver/home') {
      await container.read(rideDriverProvider.notifier).resumeFromLifecycle();
      return;
    }
    if (targetRole == 'client' || route == '/client/home') {
      await container.read(clientHomeControllerProvider.notifier).resumeFromLifecycle();
    }
  }

  AppSnackbarTone _snackbarToneForPayload(Map<String, dynamic> data) {
    return switch (data['type']?.toString()) {
      'ride_completed' => AppSnackbarTone.success,
      'ride_cancelled' ||
      'offer_rejected' ||
      'offer_invalidated' =>
        AppSnackbarTone.error,
      _ => AppSnackbarTone.info,
    };
  }
}

String? notificationRouteForPayload(Map<String, dynamic> data) {
  return notificationHomeRouteForPayload(data);
}

final notificationHandlerProvider = Provider<NotificationHandler>((ref) {
  return NotificationHandler();
});
