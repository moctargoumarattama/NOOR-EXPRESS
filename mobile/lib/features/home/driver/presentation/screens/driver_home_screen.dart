import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/app_routes.dart';
import '../../../../../core/models/app_role.dart';
import '../../../../../core/network/api_error.dart';
import '../../../../../core/services/support_contact_service.dart';
import '../../../../../core/state/session_controller.dart';
import '../../../../../shared/copy/ride_ui_copy.dart';
import '../../../../../shared/widgets/app_snackbar.dart';
import '../../../../../shared/widgets/connectivity_fallback_view.dart';
import '../../../../../shared/widgets/notification_card.dart';
import '../../../../map/presentation/controllers/map_controller.dart';
import '../../../../driver_onboarding/data/datasources/driver_profile_datasource.dart';
import '../../../../driver_onboarding/data/models/driver_profile_model.dart';
import '../../../../negotiation/data/models/ride_offer_model.dart';
import '../../../../negotiation/domain/entities/negotiation_state.dart';
import '../../../../negotiation/presentation/controllers/negotiation_controller.dart';
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

const _driverGpsStaleThreshold = Duration(minutes: 5);

enum DriverGpsStatusLevel {
  hidden,
  active,
  inactive,
  missing,
}

class DriverGpsStatusState {
  const DriverGpsStatusState({
    required this.level,
    required this.title,
    this.subtitle,
    this.showAction = false,
  });

  final DriverGpsStatusLevel level;
  final String title;
  final String? subtitle;
  final bool showAction;
}

DriverGpsStatusState buildDriverGpsStatusState({
  required bool isOnline,
  required bool hasPositionFix,
  required DateTime? lastPositionSentAt,
  required bool hasLocationProblem,
  DateTime? now,
}) {
  if (!isOnline) {
    return const DriverGpsStatusState(
      level: DriverGpsStatusLevel.hidden,
      title: '',
    );
  }
  if (!hasPositionFix || lastPositionSentAt == null) {
    return const DriverGpsStatusState(
      level: DriverGpsStatusLevel.missing,
      title: 'Position introuvable - vous etes invisible pour les passagers',
      showAction: true,
    );
  }

  final nowValue = now ?? DateTime.now();
  final isStale =
      nowValue.difference(lastPositionSentAt) > _driverGpsStaleThreshold;
  if (hasLocationProblem || isStale) {
    return const DriverGpsStatusState(
      level: DriverGpsStatusLevel.inactive,
      title: 'GPS inactif - vous ne recevez pas de demandes',
      showAction: true,
    );
  }

  return const DriverGpsStatusState(
    level: DriverGpsStatusLevel.active,
    title: 'GPS actif',
    subtitle: 'Position fraiche',
  );
}

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  final _mapKey = GlobalKey<DriverMapViewState>();
  ProviderSubscription<DriverRealtimeState>? _realtimeSubscription;
  ProviderSubscription<NegotiationState>? _negotiationSubscription;
  Timer? _notificationTimer;
  Timer? _pauseCountdownTimer;
  late Future<DriverOnboardingProfileModel?> _verificationFuture;

  bool _isMenuOpen = false;
  String? _notificationMessage;
  int? _pendingRideId;
  Map<String, dynamic>? _pendingRidePayload;
  DriverRideSheetStage _rideSheetStage = DriverRideSheetStage.idle;
  NegotiationScope? _activeNegotiationScope;
  double? _submittedOfferPrice;
  bool _isPendingRideSheetDismissed = false;
  bool _isDisposed = false;

  bool get _isUiMounted => mounted && !_isDisposed;

  @override
  void initState() {
    super.initState();
    _verificationFuture =
        ref.read(driverProfileDatasourceProvider).fetchProfile();
    _listenRealtime();
    _startPauseCountdownTicker();
    Future.microtask(_startScreen);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _notificationTimer?.cancel();
    _pauseCountdownTimer?.cancel();
    _realtimeSubscription?.close();
    _releaseInlineNegotiation(stopController: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final driverState = ref.watch(driverProvider);
    final rideState = ref.watch(rideDriverProvider);
    final sessionState = ref.watch(sessionControllerProvider);
    final mapState = ref.watch(mapControllerProvider(MapMode.driver));
    final realtimeState = ref.watch(driverRealtimeProvider);
    final profile = driverState.profile;
    final activeRide = rideState.activeRide;
    final startupIssueType = _startupIssueType(driverState, rideState);
    final startupIssueMessage = _startupIssueMessage(driverState, rideState);
    final driverStatus = _normalizedDriverStatus(profile?.driverStatus);
    final isOnline = driverStatus == 'online';
    final gpsStatus = buildDriverGpsStatusState(
      isOnline: isOnline,
      hasPositionFix: realtimeState.hasPositionFix,
      lastPositionSentAt: realtimeState.lastPositionSentAt,
      hasLocationProblem: realtimeState.locationProblemDetected,
    );
    final pauseRemainingMinutes =
        _pauseRemainingMinutes(profile?.pauseStartedAt);
    final topNoticeOffset = MediaQuery.paddingOf(context).top + 154;
    final pendingRideBase = isOnline && activeRide == null
        ? driverPendingRide(rideState.availableRides, _pendingRideId) ??
            _pendingRideFromPayload()
        : null;
    final pendingRide = _withRealtimeDistance(pendingRideBase);
    final shouldShowPendingRideFlow =
        pendingRide != null && !_isPendingRideSheetDismissed;
    final negotiationState = _activeNegotiationScope == null
        ? null
        : ref.watch(negotiationControllerProvider(_activeNegotiationScope!));
    final sheetStage = !shouldShowPendingRideFlow
        ? DriverRideSheetStage.idle
        : negotiationState?.hasSubmittedOffer == true
            ? DriverRideSheetStage.offerSent
            : _rideSheetStage;
    final isRideFlowActive =
        shouldShowPendingRideFlow && sheetStage != DriverRideSheetStage.idle;
    final sheetBusy = isRideFlowActive
        ? (negotiationState?.isSubmitting ??
            (rideState.isSubmittingAction &&
                rideState.activeRideId == pendingRide.id))
        : driverState.isUpdatingAvailability;

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DriverStatusBar(
                    status: driverStatus,
                    onMenuTap: () => setState(() => _isMenuOpen = true),
                  ),
                  const SizedBox(height: 10),
                  _DriverStatusToggle(
                    status: driverStatus,
                    isBusy: driverState.isUpdatingAvailability,
                    onSelectStatus: _setDriverStatus,
                  ),
                  if (isOnline)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: DriverGpsStatusCard(
                        state: gpsStatus,
                        onOpenGpsSettings: _openGpsSettings,
                      ),
                    ),
                  if (driverStatus == 'paused' && pauseRemainingMinutes != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 6),
                      child: Text(
                        'Pause auto dans $pauseRemainingMinutes min',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
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
              top: topNoticeOffset,
              left: 16,
              right: 16,
              child: NotificationCard(
                title: 'Nouvelle',
                message: _notificationMessage!,
                tone: NotificationCardTone.warning,
                compact: true,
              ),
            ),
          if (_notificationMessage == null && mapState.errorMessage != null)
            Positioned(
              top: topNoticeOffset,
              left: 16,
              right: 16,
              child: NotificationCard(
                title: 'Position',
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
              top: topNoticeOffset,
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
            driverStatus: driverStatus,
            isBusy: sheetBusy,
            todayRides: driverTodayRides(rideState.rides),
            todayEarnings: driverTodayEarnings(rideState.rides),
            activeRide: activeRide,
            pendingRide: pendingRide,
            flowStage: sheetStage,
            submittedOfferPrice:
                negotiationState?.submittedPrice ?? _submittedOfferPrice,
            onStart: () => _setDriverStatus('online'),
            onStop: () => _setDriverStatus('paused'),
            onOpenTracking: () => _openTracking(activeRide),
            onProposePrice: pendingRide == null
                ? null
                : () => _openManualOfferScreen(pendingRide),
            onIgnoreRide:
                pendingRide == null ? null : () => _skipRide(pendingRide.id),
            onQuickOffer: _submitQuickOffer,
            onQuickOfferSuccess: _handleQuickOfferSuccess,
            onRideRequestTimedOut: pendingRide == null
                ? null
                : () => _handleRideRequestTimeout(pendingRide.id),
            onSubmitOffer: _submitInlineOffer,
            onBackToRideReceived: _backToRideReceived,
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
            onEarningsTap: _openEarnings,
            onHistoryTap: _openDriverHistory,
            onVehicleTap: _openVehicleEditor,
            onNotificationsTap: _openNotifications,
            onSettingsTap: _openSettings,
            onHelpTap: _openHelp,
            onSupportTap: _openSupportChat,
            onReportTap: _openGeneralReport,
            onPassengerModeTap: _openPassengerMode,
            onLogout: _logout,
          ),
          if (startupIssueType != null)
            Positioned.fill(
              child: ConnectivityFallbackView(
                issueType: startupIssueType,
                message: startupIssueMessage,
                onRetry: _retryDriverBootstrap,
              ),
            ),
        ],
      ),
    );
  }

  void _listenRealtime() {
    _realtimeSubscription = ref.listenManual(
      driverRealtimeProvider,
      (previous, next) {
        if (!_isUiMounted) {
          return;
        }
        if (next.lastMessage != null &&
            next.lastMessage != previous?.lastMessage) {
          _showLiveNotification(next.lastMessage!);
          ref.read(driverRealtimeProvider.notifier).consumeMessage();
        }

        if (next.pendingRideId != null &&
            next.pendingRideId != previous?.pendingRideId) {
          _releaseInlineNegotiation();
          setState(() {
            _pendingRideId = next.pendingRideId;
            _pendingRidePayload = next.pendingRidePayload;
            _rideSheetStage = DriverRideSheetStage.rideReceived;
            _submittedOfferPrice = null;
            _isPendingRideSheetDismissed = false;
          });
          _showLiveNotification(
            'Une nouvelle course vous attend.',
          );
          ref.read(driverRealtimeProvider.notifier).consumePendingRide();
        }
      },
    );
  }

  Future<void> _startScreen() async {
    if (!_isUiMounted) {
      return;
    }
    await ref.read(driverProvider.notifier).loadProfile();
    if (!_isUiMounted) {
      return;
    }
    await ref.read(rideDriverProvider.notifier).refreshRealtimeSnapshot();
    if (!_isUiMounted) {
      return;
    }
    await ref.read(mapControllerProvider(MapMode.driver).notifier).start();
    if (!_isUiMounted) {
      return;
    }

    final session = ref.read(sessionControllerProvider);
    final driverId = session.userId;
    if (driverId != null) {
      unawaited(ref.read(driverRealtimeProvider.notifier).start(driverId));
    }
  }

  Future<void> _retryDriverBootstrap() async {
    AppSnackbar.show(
      context,
      message: RideUiCopy.refreshing,
      tone: AppSnackbarTone.info,
    );
    await _startScreen();
  }

  void _startPauseCountdownTicker() {
    _pauseCountdownTimer?.cancel();
    _pauseCountdownTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (_isUiMounted) {
          setState(() {});
        }
      },
    );
  }

  String _normalizedDriverStatus(String? rawStatus) {
    switch (rawStatus) {
      case 'online':
      case 'paused':
      case 'offline':
        return rawStatus!;
      default:
        return 'offline';
    }
  }

  int? _pauseRemainingMinutes(DateTime? pauseStartedAt) {
    if (pauseStartedAt == null) {
      return null;
    }
    final elapsed = DateTime.now().difference(pauseStartedAt);
    final remaining = const Duration(minutes: 30) - elapsed;
    if (remaining.isNegative) {
      return 0;
    }
    final minutes = (remaining.inSeconds / 60).ceil();
    return minutes < 1 ? 1 : minutes;
  }

  Future<void> _setDriverStatus(String status) async {
    final error = await ref.read(driverProvider.notifier).updateStatus(status);
    // `use_build_context_synchronously`: guard `context` (State.context) after an async gap.
    if (!mounted || _isDisposed) {
      return;
    }

    final fallbackMessage = switch (status) {
      'online' => 'Vous etes en ligne.',
      'paused' => 'Vous etes en pause.',
      _ => 'Vous etes hors ligne.',
    };
    AppSnackbar.show(
      context,
      message: _humanizeMessage(error, fallback: fallbackMessage),
      tone: error == null ? AppSnackbarTone.success : AppSnackbarTone.error,
    );
  }

  Future<void> _toggleAvailability(bool value) async {
    final targetStatus = value ? 'online' : 'paused';
    await _setDriverStatus(targetStatus);
  }

  Future<void> _skipRide(int rideId) async {
    _releaseInlineNegotiation();
    setState(() {
      _pendingRideId = null;
      _pendingRidePayload = null;
      _rideSheetStage = DriverRideSheetStage.idle;
      _submittedOfferPrice = null;
      _isPendingRideSheetDismissed = false;
    });
    final error =
        await ref.read(rideDriverProvider.notifier).rejectRide(rideId);
    // `use_build_context_synchronously`: guard `context` (State.context) after an async gap.
    if (!mounted || _isDisposed) {
      return;
    }
    AppSnackbar.show(
      context,
      message: _humanizeMessage(error, fallback: 'Cette course est ignoree.'),
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
      message: 'On retrouve votre position...',
      tone: AppSnackbarTone.info,
    );
    await ref.read(mapControllerProvider(MapMode.driver).notifier).start();
    // `use_build_context_synchronously`: guard `context` (State.context) after an async gap.
    if (!mounted || _isDisposed) {
      return;
    }
    _mapKey.currentState?.recenter();
    final mapState = ref.read(mapControllerProvider(MapMode.driver));
    AppSnackbar.show(
      context,
      message: _humanizeMessage(
        mapState.errorMessage,
        fallback: 'Votre position est a jour.',
      ),
      tone: mapState.errorMessage == null
          ? AppSnackbarTone.success
          : AppSnackbarTone.error,
    );
  }

  void _openManualOfferScreen(DriverRide ride) {
    context.push(
      AppRoutes.driverOffer(ride.id),
      extra: _pendingRidePayload ??
          {
            'ride_id': ride.id,
            'pickup_location': ride.pickupLocation,
            'dropoff_location': ride.dropoffLocation,
            'client_price': ride.estimatedPrice,
            'driver_distance_km': ride.distanceToPickupKm,
          },
    );
  }

  Future<bool> _submitQuickOffer(double proposedPrice) async {
    final ride = _currentPendingRide();
    if (ride == null) {
      return false;
    }
    final scope = _bindInlineNegotiation(ride);
    await ref
        .read(negotiationControllerProvider(scope).notifier)
        .submitOffer(proposedPrice);
    if (!_isUiMounted) {
      return false;
    }
    final nextState = ref.read(negotiationControllerProvider(scope));
    return nextState.hasSubmittedOffer;
  }

  void _handleQuickOfferSuccess(double offeredPrice) {
    if (!_isUiMounted) {
      return;
    }
    setState(() {
      _rideSheetStage = DriverRideSheetStage.idle;
      _submittedOfferPrice = offeredPrice;
      _isPendingRideSheetDismissed = true;
    });
    AppSnackbar.show(
      context,
      message: 'Offre envoyee ✓',
      tone: AppSnackbarTone.success,
    );
  }

  Future<void> _handleRideRequestTimeout(int rideId) async {
    if (!_isUiMounted) {
      return;
    }
    await _skipRide(rideId);
  }

  Future<void> _submitInlineOffer(double proposedPrice) async {
    final submitted = await _submitQuickOffer(proposedPrice);
    if (!_isUiMounted || !submitted || _isPendingRideSheetDismissed) {
      return;
    }
    setState(() {
      _rideSheetStage = DriverRideSheetStage.offerSent;
      _submittedOfferPrice = proposedPrice;
    });
  }

  void _backToRideReceived() {
    setState(() {
      _rideSheetStage = DriverRideSheetStage.rideReceived;
      _isPendingRideSheetDismissed = false;
    });
  }

  NegotiationScope _bindInlineNegotiation(DriverRide ride) {
    final scope = _negotiationScopeForRide(ride);
    if (_activeNegotiationScope == scope && _negotiationSubscription != null) {
      return scope;
    }

    _releaseInlineNegotiation();
    _activeNegotiationScope = scope;
    _negotiationSubscription = ref.listenManual<NegotiationState>(
      negotiationControllerProvider(scope),
      (previous, next) {
        if (!_isUiMounted) {
          return;
        }
        if (next.toastMessage != null &&
            next.toastMessage != previous?.toastMessage) {
          AppSnackbar.show(
            context,
            message: _humanizeMessage(next.toastMessage!),
            tone: AppSnackbarTone.info,
          );
          ref
              .read(negotiationControllerProvider(scope).notifier)
              .consumeToast();
        }
        if (next.errorMessage != null &&
            next.errorMessage != previous?.errorMessage) {
          AppSnackbar.show(
            context,
            message: _humanizeMessage(next.errorMessage!),
            tone: AppSnackbarTone.error,
          );
        }
        if (next.hasSubmittedOffer &&
            !(previous?.hasSubmittedOffer ?? false) &&
            !_isPendingRideSheetDismissed) {
          setState(() {
            _rideSheetStage = DriverRideSheetStage.offerSent;
            _submittedOfferPrice = next.submittedPrice;
          });
        }
        final trackingRideId = next.navigateToTrackingRideId;
        if (trackingRideId != null &&
            trackingRideId != previous?.navigateToTrackingRideId) {
          final notifier =
              ref.read(negotiationControllerProvider(scope).notifier);
          notifier.consumeNavigation();
          unawaited(notifier.stop());
          _releaseInlineNegotiation(stopController: false);
          setState(() {
            _pendingRideId = null;
            _pendingRidePayload = null;
            _rideSheetStage = DriverRideSheetStage.idle;
            _submittedOfferPrice = null;
            _isPendingRideSheetDismissed = false;
          });
          context.go(AppRoutes.driverMapWithRide(trackingRideId));
          return;
        }
        if (next.shouldCloseToHome && !(previous?.shouldCloseToHome ?? false)) {
          final notifier =
              ref.read(negotiationControllerProvider(scope).notifier);
          notifier.consumeCloseAction();
          unawaited(notifier.stop());
          _releaseInlineNegotiation(stopController: false);
          setState(() {
            _pendingRideId = null;
            _pendingRidePayload = null;
            _rideSheetStage = DriverRideSheetStage.idle;
            _submittedOfferPrice = null;
            _isPendingRideSheetDismissed = false;
          });
        }
      },
    );
    unawaited(ref.read(negotiationControllerProvider(scope).notifier).start());
    return scope;
  }

  NegotiationScope _negotiationScopeForRide(DriverRide ride) {
    return NegotiationScope(
      mode: NegotiationMode.driver,
      rideId: ride.id,
      initialRide: NegotiationRideModel(
        rideId: ride.id,
        pickup: ride.pickupLocation,
        dropoff: ride.dropoffLocation,
        clientPrice: ride.estimatedPrice,
        status: ride.status,
        distanceKm: ride.distanceToPickupKm,
      ),
    );
  }

  void _releaseInlineNegotiation({bool stopController = true}) {
    final scope = _activeNegotiationScope;
    _negotiationSubscription?.close();
    _negotiationSubscription = null;
    _activeNegotiationScope = null;
    if (stopController && scope != null) {
      unawaited(ref.read(negotiationControllerProvider(scope).notifier).stop());
    }
  }

  DriverRide? _currentPendingRide() {
    final rideState = ref.read(rideDriverProvider);
    if (rideState.activeRide != null) {
      return null;
    }
    final base = driverPendingRide(rideState.availableRides, _pendingRideId) ??
        _pendingRideFromPayload();
    return _withRealtimeDistance(base);
  }

  DriverRide? _pendingRideFromPayload() {
    final payload = _pendingRidePayload;
    if (payload == null) {
      return null;
    }
    final rideId = _pendingRideId ??
        _intFromPayload(payload['ride_id'] ?? payload['ride_request_id']);
    if (rideId == null) {
      return null;
    }
    return DriverRide(
      id: rideId,
      pickupLocation: _stringFromPayload(
        payload['pickup_location'] ?? payload['pickup'],
      ),
      dropoffLocation: _stringFromPayload(
        payload['dropoff_location'] ?? payload['dropoff'],
      ),
      status: 'pending',
      estimatedPrice: _doubleFromPayload(
            payload['client_price'] ?? payload['estimated_price'],
          ) ??
          0,
      distanceToPickupKm: _distanceFromPayload(payload),
      createdAt: DateTime.now(),
    );
  }

  DriverRide? _withRealtimeDistance(DriverRide? ride) {
    if (ride == null || ride.distanceToPickupKm != null) {
      return ride;
    }
    final distance = _distanceFromPayload(_pendingRidePayload);
    if (distance == null) {
      return ride;
    }
    return ride.copyWith(distanceToPickupKm: distance);
  }

  double? _distanceFromPayload(Map<String, dynamic>? payload) {
    if (payload == null) {
      return null;
    }
    final value = payload['driver_distance_km'] ?? payload['distance_km'];
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  int? _intFromPayload(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  double? _doubleFromPayload(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  String _stringFromPayload(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return 'A confirmer';
    }
    return text;
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

  void _openEarnings() {
    _closeMenu();
    context.push(AppRoutes.driverEarnings);
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

  void _openSupportChat() {
    _closeMenu();
    unawaited(_launchSupportChat());
  }

  void _openSettings() {
    _closeMenu();
    context.push(AppRoutes.settings);
  }

  void _openNotifications() {
    _closeMenu();
    context.push(AppRoutes.notifications);
  }

  Future<void> _launchSupportChat() async {
    final result = await ref
        .read(supportContactServiceProvider)
        .openSupportChat(AppRole.driver);
    // `use_build_context_synchronously`: guard `context` (State.context) after an async gap.
    if (!mounted ||
        _isDisposed ||
        result.type != SupportContactResultType.failed) {
      return;
    }
    AppSnackbar.show(
      context,
      message: 'Impossible d ouvrir WhatsApp pour le moment.',
      tone: AppSnackbarTone.error,
    );
  }

  Future<void> _openGeneralReport() async {
    _closeMenu();
    final activeRide = ref.read(rideDriverProvider).activeRide;
    final trackingDatasource = ref.read(trackingRemoteDatasourceProvider);
    final draft = await showRideReportBottomSheet(
      context,
      onSubmit: (draft) async {
        if (activeRide == null) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
          return;
        }
        await trackingDatasource.reportRide(
          rideId: activeRide.id,
          reason: draft.reason,
          description: draft.description,
        );
      },
    );
    // `use_build_context_synchronously`: guard `context` (State.context) after an async gap.
    if (!mounted || _isDisposed || draft == null) {
      return;
    }
    AppSnackbar.show(
      context,
      message: 'Signalement envoye.',
      tone: AppSnackbarTone.success,
    );
  }

  Future<void> _openGpsSettings() async {
    await ref
        .read(mapControllerProvider(MapMode.driver).notifier)
        .openLocationSettings();
  }

  ApiIssueType? _startupIssueType(
    DriverState driverState,
    RideDriverState rideState,
  ) {
    final hasHomeData = driverState.profile != null ||
        rideState.activeRide != null ||
        rideState.availableRides.isNotEmpty ||
        rideState.rides.isNotEmpty;
    if (hasHomeData || driverState.isLoading) {
      return null;
    }
    final message = driverState.errorMessage ??
        rideState.historyErrorMessage ??
        rideState.availableErrorMessage;
    final issue = ApiErrorPayload.classifyMessage(message);
    return issue == ApiIssueType.unknown ? null : issue;
  }

  String? _startupIssueMessage(
    DriverState driverState,
    RideDriverState rideState,
  ) {
    final message = driverState.errorMessage ??
        rideState.historyErrorMessage ??
        rideState.availableErrorMessage;
    final trimmed = message?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
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
    if (!_isUiMounted) {
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
      if (_isUiMounted) {
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

class DriverGpsStatusCard extends StatelessWidget {
  const DriverGpsStatusCard({
    super.key,
    required this.state,
    required this.onOpenGpsSettings,
  });

  final DriverGpsStatusState state;
  final Future<void> Function() onOpenGpsSettings;

  @override
  Widget build(BuildContext context) {
    switch (state.level) {
      case DriverGpsStatusLevel.hidden:
        return const SizedBox.shrink();
      case DriverGpsStatusLevel.active:
        return _GpsActivePill(title: state.title, subtitle: state.subtitle);
      case DriverGpsStatusLevel.inactive:
        return _GpsWarningBanner(
          title: state.title,
          color: const Color(0xFFF29A2E),
          actionLabel: 'Activer le GPS',
          onOpenGpsSettings: onOpenGpsSettings,
        );
      case DriverGpsStatusLevel.missing:
        return _GpsWarningBanner(
          title: state.title,
          color: const Color(0xFFD94848),
          actionLabel: 'Activer le GPS',
          onOpenGpsSettings: onOpenGpsSettings,
        );
    }
  }
}

class _GpsActivePill extends StatelessWidget {
  const _GpsActivePill({
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF114B34).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.satellite_alt_rounded,
              color: Color(0xFF9AE6B4), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subtitle == null ? title : '$title - $subtitle',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GpsWarningBanner extends StatelessWidget {
  const _GpsWarningBanner({
    required this.title,
    required this.color,
    required this.actionLabel,
    required this.onOpenGpsSettings,
  });

  final String title;
  final Color color;
  final String actionLabel;
  final Future<void> Function() onOpenGpsSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.satellite_alt_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              unawaited(onOpenGpsSettings());
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverStatusToggle extends StatelessWidget {
  const _DriverStatusToggle({
    required this.status,
    required this.isBusy,
    required this.onSelectStatus,
  });

  final String status;
  final bool isBusy;
  final ValueChanged<String> onSelectStatus;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: _StatusPillButton(
                label: 'Hors ligne',
                color: const Color(0xFF8A8D93),
                isSelected: status == 'offline',
                isBusy: isBusy,
                onTap: () => onSelectStatus('offline'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _StatusPillButton(
                label: 'En ligne',
                color: const Color(0xFF1B8A5A),
                isSelected: status == 'online',
                isBusy: isBusy,
                onTap: () => onSelectStatus('online'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _StatusPillButton(
                label: 'Pause',
                color: const Color(0xFFF29A2E),
                isSelected: status == 'paused',
                isBusy: isBusy,
                onTap: () => onSelectStatus('paused'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPillButton extends StatelessWidget {
  const _StatusPillButton({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.isBusy,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool isSelected;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isBusy ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
