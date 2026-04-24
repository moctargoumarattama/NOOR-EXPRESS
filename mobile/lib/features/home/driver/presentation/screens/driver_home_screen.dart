import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/app_routes.dart';
import '../../../../../core/state/session_controller.dart';
import '../../../../../shared/copy/ride_ui_copy.dart';
import '../../../../../shared/widgets/app_snackbar.dart';
import '../../../../../shared/widgets/notification_card.dart';
import '../../../../map/presentation/controllers/map_controller.dart';
import '../../../../driver_onboarding/data/datasources/driver_profile_datasource.dart';
import '../../../../driver_onboarding/data/models/driver_profile_model.dart';
import '../../../../ride_tracking/data/datasources/tracking_remote_datasource.dart';
import '../../../../ride_tracking/presentation/widgets/report_bottom_sheet.dart';
import '../../data/models/driver_ride.dart';
import '../controllers/driver_controller.dart';
import '../controllers/driver_home_metrics.dart';
import '../controllers/driver_realtime_controller.dart';
import '../controllers/ride_driver_controller.dart';
import '../widgets/driver_bottom_sheet.dart';
import '../widgets/driver_hamburger_menu.dart';
import '../widgets/driver_map_view.dart';
import '../widgets/driver_status_bar.dart';
import '../widgets/driver_verification_banner.dart';
import '../widgets/recenter_map_button.dart';
import '../widgets/ride_request_popup.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  final _mapKey = GlobalKey<DriverMapViewState>();
  ProviderSubscription<DriverRealtimeState>? _realtimeSubscription;
  Timer? _notificationTimer;
  late Future<DriverOnboardingProfileModel?> _verificationFuture;

  bool _isMenuOpen = false;
  String? _notificationMessage;
  int? _pendingRideId;
  Map<String, dynamic>? _pendingRidePayload;

  @override
  void initState() {
    super.initState();
    _verificationFuture =
        ref.read(driverProfileDatasourceProvider).fetchProfile();
    _listenRealtime();
    Future.microtask(_startScreen);
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _realtimeSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final driverState = ref.watch(driverProvider);
    final rideState = ref.watch(rideDriverProvider);
    final sessionState = ref.watch(sessionControllerProvider);
    final mapState = ref.watch(mapControllerProvider(MapMode.driver));
    final profile = driverState.profile;
    final activeRide = driverActiveRide(rideState.rides);
    final isOnline = profile?.isAvailable ?? false;
    final pendingRide = isOnline && activeRide == null
        ? driverPendingRide(rideState.availableRides, _pendingRideId)
        : null;
    final status = activeRide != null
        ? 'busy'
        : isOnline
            ? 'online'
            : 'offline';

    return Scaffold(
      backgroundColor: const Color(0xFF101820),
      body: Stack(
        children: [
          Positioned.fill(
            child: DriverMapView(
              key: _mapKey,
              position: mapState.currentPosition,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: DriverStatusBar(
                status: status,
                onMenuTap: () => setState(() => _isMenuOpen = true),
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: MediaQuery.sizeOf(context).height * 0.34,
            child: RecenterMapButton(
              onTap: _retryLocationAndRecenter,
            ),
          ),
          if (_notificationMessage != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 84,
              left: 16,
              right: 16,
              child: NotificationCard(
                title: 'Mise a jour',
                message: _notificationMessage!,
                tone: NotificationCardTone.warning,
                compact: true,
              ),
            ),
          if (_notificationMessage == null && mapState.errorMessage != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 84,
              left: 16,
              right: 16,
              child: NotificationCard(
                title: 'GPS',
                message: _humanizeMessage(
                  mapState.errorMessage,
                  fallback: RideUiCopy.gpsUnavailable,
                ),
                tone: NotificationCardTone.warning,
                compact: true,
              ),
            ),
          if (_notificationMessage == null && mapState.errorMessage == null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 84,
              left: 16,
              right: 16,
              child: FutureBuilder<DriverOnboardingProfileModel?>(
                future: _verificationFuture,
                builder: (context, snapshot) {
                  final profile = snapshot.data;
                  if (profile?.verificationStatus ==
                      DriverVerificationStatus.verified) {
                    return const SizedBox.shrink();
                  }
                  return DriverVerificationBanner(
                    profile: profile,
                    onTap: () {
                      context.push(profile == null
                          ? AppRoutes.driverOnboarding
                          : AppRoutes.driverOnboardingStatus);
                    },
                  );
                },
              ),
            ),
          DriverBottomSheet(
            isOnline: isOnline,
            isBusy: driverState.isUpdatingAvailability,
            todayRides: driverTodayRides(rideState.rides),
            todayEarnings: driverTodayEarnings(rideState.rides),
            activeRide: activeRide,
            onStart: () => _toggleAvailability(true),
            onStop: () => _toggleAvailability(false),
            onOpenTracking: () => _openTracking(activeRide),
          ),
          if (pendingRide != null)
            RideRequestPopup(
              key: ValueKey(pendingRide.id),
              ride: pendingRide,
              isSubmitting: rideState.isSubmittingAction &&
                  rideState.activeRideId == pendingRide.id,
              onSend: (_) => _openOffer(pendingRide.id),
              onSkip: () => _skipRide(pendingRide.id),
            ),
          DriverHamburgerMenu(
            isOpen: _isMenuOpen,
            profile: profile,
            driverName: sessionState.name ?? 'Driver Noor',
            isOnline: isOnline,
            isUpdatingAvailability: driverState.isUpdatingAvailability,
            onClose: _closeMenu,
            onToggleAvailability: _toggleAvailability,
            onProfileTap: _openDriverProfile,
            onStatsTap: _openStats,
            onHistoryTap: _openDriverHistory,
            onVehicleTap: _openVehicleEditor,
            onNotificationsTap: _openNotifications,
            onSettingsTap: _openSettings,
            onHelpTap: _openHelp,
            onReportTap: _openGeneralReport,
            onPassengerModeTap: _openPassengerMode,
            onLogout: _logout,
          ),
        ],
      ),
    );
  }

  void _listenRealtime() {
    _realtimeSubscription = ref.listenManual(
      driverRealtimeProvider,
      (previous, next) {
        if (next.lastMessage != null &&
            next.lastMessage != previous?.lastMessage) {
          _showLiveNotification(next.lastMessage!);
          ref.read(driverRealtimeProvider.notifier).consumeMessage();
        }

        if (next.pendingRideId != null &&
            next.pendingRideId != previous?.pendingRideId) {
          setState(() {
            _pendingRideId = next.pendingRideId;
            _pendingRidePayload = next.pendingRidePayload;
          });
          _showLiveNotification(
            'Nouvelle demande recue. Repondez avant expiration.',
          );
          ref.read(driverRealtimeProvider.notifier).consumePendingRide();
        }
      },
    );
  }

  Future<void> _startScreen() async {
    await ref.read(driverProvider.notifier).loadProfile();
    await ref.read(rideDriverProvider.notifier).refreshRealtimeSnapshot();
    await ref.read(mapControllerProvider(MapMode.driver).notifier).start();

    final session = ref.read(sessionControllerProvider);
    final driverId = session.userId;
    if (driverId != null) {
      unawaited(ref.read(driverRealtimeProvider.notifier).start(driverId));
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    final error =
        await ref.read(driverProvider.notifier).updateAvailability(value);
    if (!mounted) {
      return;
    }
    AppSnackbar.show(
      context,
      message: _humanizeMessage(
        error,
        fallback: value
            ? 'Vous etes visible pour les clients.'
            : 'Vous n apparaissez plus dans les demandes.',
      ),
      tone: error == null ? AppSnackbarTone.success : AppSnackbarTone.error,
    );
  }

  Future<void> _skipRide(int rideId) async {
    setState(() {
      _pendingRideId = null;
      _pendingRidePayload = null;
    });
    final error =
        await ref.read(rideDriverProvider.notifier).rejectRide(rideId);
    if (!mounted) {
      return;
    }
    AppSnackbar.show(
      context,
      message: _humanizeMessage(error, fallback: 'Demande ignoree.'),
      tone: error == null ? AppSnackbarTone.info : AppSnackbarTone.error,
    );
  }

  void _openVehicleEditor() {
    _closeMenu();
    context.push(AppRoutes.driverVehicle);
  }

  Future<void> _retryLocationAndRecenter() async {
    AppSnackbar.show(
      context,
      message: 'Activation GPS en cours...',
      tone: AppSnackbarTone.info,
    );
    await ref.read(mapControllerProvider(MapMode.driver).notifier).start();
    if (!mounted) {
      return;
    }
    _mapKey.currentState?.recenter();
    final mapState = ref.read(mapControllerProvider(MapMode.driver));
    AppSnackbar.show(
      context,
      message: _humanizeMessage(
        mapState.errorMessage,
        fallback: 'Position GPS activee.',
      ),
      tone: mapState.errorMessage == null
          ? AppSnackbarTone.success
          : AppSnackbarTone.error,
    );
  }

  void _openOffer(int rideId) {
    final payload = _pendingRidePayload;
    setState(() {
      _pendingRideId = null;
      _pendingRidePayload = null;
    });
    context.push(AppRoutes.driverOffer(rideId), extra: payload);
  }

  void _openTracking(DriverRide? ride) {
    if (ride == null) {
      return;
    }
    context.push(AppRoutes.driverMapWithRide(ride.id));
  }

  void _openStats() {
    _closeMenu();
    context.push(AppRoutes.driverStats);
  }

  void _openDriverProfile() {
    _closeMenu();
    context.push(AppRoutes.driverProfile);
  }

  void _openDriverHistory() {
    _closeMenu();
    context.push(AppRoutes.driverHistory);
  }

  void _openHelp() {
    _closeMenu();
    context.push(AppRoutes.help);
  }

  void _openSettings() {
    _closeMenu();
    context.push(AppRoutes.settings);
  }

  void _openNotifications() {
    _closeMenu();
    context.push(AppRoutes.notifications);
  }

  Future<void> _openGeneralReport() async {
    _closeMenu();
    final activeRide = driverActiveRide(ref.read(rideDriverProvider).rides);
    final draft = await showRideReportBottomSheet(
      context,
      onSubmit: (draft) async {
        if (activeRide == null) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
          return;
        }
        await ref.read(trackingRemoteDatasourceProvider).reportRide(
              rideId: activeRide.id,
              reason: draft.reason,
              description: draft.description,
            );
      },
    );
    if (mounted && draft != null) {
      AppSnackbar.show(
        context,
        message: 'Signalement envoye.',
        tone: AppSnackbarTone.success,
      );
    }
  }

  void _openPassengerMode() {
    _closeMenu();
    context.go(AppRoutes.clientHome);
  }

  Future<void> _logout() async {
    _closeMenu();
    await ref.read(driverRealtimeProvider.notifier).stop();
    await ref.read(sessionControllerProvider.notifier).logout();
  }

  void _closeMenu() {
    if (_isMenuOpen) {
      setState(() => _isMenuOpen = false);
    }
  }

  void _showLiveNotification(String message) {
    if (!mounted) {
      return;
    }
    final humanized = _humanizeMessage(message, fallback: message);
    setState(() => _notificationMessage = humanized);
    AppSnackbar.show(
      context,
      message: humanized,
      tone: AppSnackbarTone.info,
    );
    _notificationTimer?.cancel();
    _notificationTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _notificationMessage = null);
      }
    });
  }

  String _humanizeMessage(String? message, {String? fallback}) {
    final trimmed = message?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return fallback ?? '';
    }

    final value = trimmed.toLowerCase();
    if (value.contains('gps')) {
      return RideUiCopy.gpsUnavailable;
    }
    if (value.contains('network') ||
        value.contains('connexion') ||
        value.contains('socket') ||
        value.contains('timeout')) {
      return RideUiCopy.networkError;
    }
    if ((value.contains('aucun') && value.contains('chauffeur')) ||
        value.contains('no driver')) {
      return RideUiCopy.noDriverAvailable;
    }
    if (value.contains('annul')) {
      return RideUiCopy.rideCancelled;
    }

    return trimmed;
  }
}
