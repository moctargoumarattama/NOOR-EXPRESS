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
  late Future<DriverOnboardingProfileModel?> _verificationFuture;

  bool _isMenuOpen = false;
  String? _notificationMessage;
  int? _pendingRideId;
  Map<String, dynamic>? _pendingRidePayload;
  DriverRideSheetStage _rideSheetStage = DriverRideSheetStage.idle;
  NegotiationScope? _activeNegotiationScope;
  double? _submittedOfferPrice;

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
    _releaseInlineNegotiation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final driverState = ref.watch(driverProvider);
    final rideState = ref.watch(rideDriverProvider);
    final sessionState = ref.watch(sessionControllerProvider);
    final mapState = ref.watch(mapControllerProvider(MapMode.driver));
    final profile = driverState.profile;
    final activeRide = rideState.activeRide;
    final isOnline = profile?.isAvailable ?? false;
    final pendingRideBase = isOnline && activeRide == null
        ? driverPendingRide(rideState.availableRides, _pendingRideId) ??
            _pendingRideFromPayload()
        : null;
    final pendingRide = _withRealtimeDistance(pendingRideBase);
    final negotiationState = _activeNegotiationScope == null
        ? null
        : ref.watch(negotiationControllerProvider(_activeNegotiationScope!));
    final sheetStage = pendingRide == null
        ? DriverRideSheetStage.idle
        : negotiationState?.hasSubmittedOffer == true
            ? DriverRideSheetStage.offerSent
            : _rideSheetStage;
    final isRideFlowActive =
        pendingRide != null && sheetStage != DriverRideSheetStage.idle;
    final sheetBusy = isRideFlowActive
        ? (negotiationState?.isSubmitting ??
            (rideState.isSubmittingAction &&
                rideState.activeRideId == pendingRide.id))
        : driverState.isUpdatingAvailability;
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
                title: 'Nouvelle',
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
            isBusy: sheetBusy,
            todayRides: driverTodayRides(rideState.rides),
            todayEarnings: driverTodayEarnings(rideState.rides),
            activeRide: activeRide,
            pendingRide: pendingRide,
            flowStage: sheetStage,
            submittedOfferPrice:
                negotiationState?.submittedPrice ?? _submittedOfferPrice,
            onStart: () => _toggleAvailability(true),
            onStop: () => _toggleAvailability(false),
            onOpenTracking: () => _openTracking(activeRide),
            onProposePrice: pendingRide == null
                ? null
                : () => _showPriceProposal(pendingRide),
            onIgnoreRide:
                pendingRide == null ? null : () => _skipRide(pendingRide.id),
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
          _releaseInlineNegotiation();
          setState(() {
            _pendingRideId = next.pendingRideId;
            _pendingRidePayload = next.pendingRidePayload;
            _rideSheetStage = DriverRideSheetStage.rideReceived;
            _submittedOfferPrice = null;
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
            ? 'Vous recevez maintenant les demandes.'
            : 'Vous ne recevez plus de demande pour le moment.',
      ),
      tone: error == null ? AppSnackbarTone.success : AppSnackbarTone.error,
    );
  }

  Future<void> _skipRide(int rideId) async {
    _releaseInlineNegotiation();
    setState(() {
      _pendingRideId = null;
      _pendingRidePayload = null;
      _rideSheetStage = DriverRideSheetStage.idle;
      _submittedOfferPrice = null;
    });
    final error =
        await ref.read(rideDriverProvider.notifier).rejectRide(rideId);
    if (!mounted) {
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
    if (!mounted) {
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

  void _showPriceProposal(DriverRide ride) {
    _bindInlineNegotiation(ride);
    setState(() {
      _rideSheetStage = DriverRideSheetStage.priceProposal;
      _submittedOfferPrice = null;
    });
  }

  Future<void> _submitInlineOffer(double proposedPrice) async {
    final ride = _currentPendingRide();
    if (ride == null) {
      return;
    }
    final scope = _bindInlineNegotiation(ride);
    await ref
        .read(negotiationControllerProvider(scope).notifier)
        .submitOffer(proposedPrice);
    if (!mounted) {
      return;
    }
    final nextState = ref.read(negotiationControllerProvider(scope));
    if (nextState.hasSubmittedOffer) {
      setState(() {
        _rideSheetStage = DriverRideSheetStage.offerSent;
        _submittedOfferPrice = nextState.submittedPrice ?? proposedPrice;
      });
    }
  }

  void _backToRideReceived() {
    setState(() => _rideSheetStage = DriverRideSheetStage.rideReceived);
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
        if (!mounted) {
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
        if (next.hasSubmittedOffer && !(previous?.hasSubmittedOffer ?? false)) {
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
    final activeRide = ref.read(rideDriverProvider).activeRide;
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
