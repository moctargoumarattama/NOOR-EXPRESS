import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/models/app_role.dart';
import '../../../../core/services/support_contact_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/copy/ride_ui_copy.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../data/models/ride_tracking_model.dart';
import '../../domain/entities/tracking_state.dart';
import '../controllers/tracking_controller.dart';
import '../services/navigation_service.dart';
import 'ride_chat_screen.dart';
import '../tracking_status_presenter.dart';
import '../widgets/bottom_ride_sheet.dart';
import '../widgets/map_view.dart';
import '../widgets/rating_bottom_sheet.dart';
import '../widgets/report_bottom_sheet.dart';
import '../widgets/ride_chat_fab.dart';
import '../widgets/ride_detail_section.dart';
import '../widgets/ride_status_banner.dart';
import '../widgets/tracking_shell_widgets.dart';

class DriverTrackingScreen extends ConsumerStatefulWidget {
  const DriverTrackingScreen({
    super.key,
    this.rideId,
  });

  final int? rideId;

  @override
  ConsumerState<DriverTrackingScreen> createState() =>
      _DriverTrackingScreenState();
}

class _DriverTrackingScreenState extends ConsumerState<DriverTrackingScreen> {
  ProviderSubscription<TrackingState>? _subscription;
  Timer? _ratingPromptTimer;
  int? _ratingPromptRideId;
  int? _autoPromptedRideId;
  bool _isDisposed = false;

  TrackingControllerScope get _scope => TrackingControllerScope(
        mode: TrackingMode.driver,
        rideId: widget.rideId,
      );

  bool get _isUiMounted => mounted && !_isDisposed;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual<TrackingState>(
      trackingControllerProvider(_scope),
      (previous, next) {
        _syncAutoRatingPrompt(previous?.ride, next.ride);
        final message = next.toastMessage;
        if (message == null ||
            message == previous?.toastMessage ||
            !_isUiMounted) {
          return;
        }
        AppSnackbar.show(context, message: _humanizeMessage(message));
        ref.read(trackingControllerProvider(_scope).notifier).consumeToast();
      },
    );

    unawaited(ref.read(trackingControllerProvider(_scope).notifier).start());
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cancelAutoRatingPrompt();
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trackingControllerProvider(_scope));
    final ride = state.ride;
    final pickup = ride?.pickupPosition;
    final statusPresentation = buildDriverTrackingStatusPresentation(ride);
    final recoveryMessage = _recoveryMessage(state);
    final showPassengerReadyBanner =
        (state.passengerReadyBannerMessage ?? '').isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: Stack(
        children: [
          Positioned.fill(
            child: MapView(
              status: ride?.status ?? RideTrackingStatus.accepted,
              routePoints: state.routePoints,
              currentPosition: null,
              driverPosition: state.currentPosition,
              pickupPosition: pickup,
              destinationPosition: ride?.dropoffPosition,
              driverHeadingDegrees: state.driverHeadingDegrees,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.42),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.34),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 220),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TrackingTopBar(
                    connectionState: state.connectionState,
                    etaMinutes: state.isEtaReliable ? state.etaMinutes : null,
                    distanceRemainingKm: state.distanceRemainingKm,
                    onBack: () {
                      if (context.canPop()) {
                        context.pop();
                        return;
                      }
                      context.go(AppRoutes.driverHome);
                    },
                  ),
                  if (recoveryMessage != null) ...[
                    const SizedBox(height: 14),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: TrackingRecoveryBanner(
                        key: ValueKey(
                          'driver-recovery-${state.connectionState.name}-${state.errorMessage}',
                        ),
                        connectionState: state.connectionState,
                        message: recoveryMessage,
                        isLoading: _recoveryIsLoading(state),
                        onRefresh: () => ref
                            .read(trackingControllerProvider(_scope).notifier)
                            .refresh(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: RideStatusBanner(
                      key: ValueKey(
                        'driver-banner-${ride?.status.name ?? 'unknown'}-${statusPresentation.showSpinner}',
                      ),
                      status: ride?.status ?? RideTrackingStatus.accepted,
                      title: statusPresentation.title,
                      subtitle: statusPresentation.subtitle,
                      showSpinner: ride == null
                          ? state.isLoading
                          : statusPresentation.showSpinner,
                    ),
                  ),
                  if (ride?.passengerReadyAt != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.nigerGreenSoft,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.nigerGreenBorder),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: AppColors.nigerGreen,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Passager pret',
                            style: TextStyle(
                              color: AppColors.nigerGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (ride == null && !state.isLoading) ...[
                    const SizedBox(height: 20),
                    const TrackingEmptyCard(
                      title: 'Aucune course active',
                      subtitle:
                          'Acceptez une demande depuis l espace chauffeur pour relancer le suivi.',
                    ),
                  ],
                ],
              ),
            ),
            ),
          Positioned(
            top: 74,
            left: 16,
            right: 16,
            child: IgnorePointer(
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                offset: showPassengerReadyBanner
                    ? Offset.zero
                    : const Offset(0, -1.4),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: showPassengerReadyBanner ? 1 : 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D7A37),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Text(
                      state.passengerReadyBannerMessage ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (ride != null)
            Positioned(
              left: 18,
              bottom: 154,
              child: TrackingSupportButton(
                onPressed: _openSupportChat,
              ),
            ),
          if (ride != null)
            BottomRideSheet(
              floatingAction: _buildChatAction(state),
              secondaryAction: _buildSecondaryActions(state),
              primaryAction: _buildPrimaryAction(state),
              child: RideDetailSection(
                ride: ride,
                counterpart: state.counterpart,
                roleLabel: 'Client',
                distanceRemainingKm: state.distanceRemainingKm,
                statusLabel: trackingStatusLabel(ride.status),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _buildPrimaryAction(TrackingState state) {
    final ride = state.ride;
    if (ride == null) {
      return null;
    }

    if (ride.isAccepted) {
      return AppButton(
        label: 'Je suis arrive',
        isLoading: state.isActionLoading,
        onPressed: state.isActionLoading
            ? null
            : () {
                ref
                    .read(trackingControllerProvider(_scope).notifier)
                    .markArrived();
              },
      );
    }

    if (ride.isArrived) {
      return AppButton(
        label: 'Demarrer la course',
        isLoading: state.isActionLoading,
        onPressed: state.isActionLoading
            ? null
            : () {
                ref
                    .read(trackingControllerProvider(_scope).notifier)
                    .startRide();
              },
      );
    }

    if (ride.isStarted) {
      return AppButton(
        label: 'Terminer la course',
        isLoading: state.isActionLoading,
        onPressed: state.isActionLoading
            ? null
            : () {
                ref
                    .read(trackingControllerProvider(_scope).notifier)
                    .completeRide();
              },
      );
    }

    if (ride.canRateClient) {
      return AppButton(
        label: 'Noter le client',
        isLoading: state.isActionLoading,
        onPressed: state.isActionLoading ? null : _openClientRatingSheet,
      );
    }

    return null;
  }

  Widget? _buildSecondaryActions(TrackingState state) {
    final ride = state.ride;
    if (ride == null) {
      return null;
    }

    final actions = <Widget>[
      ..._buildNavigationActions(
        ride: ride,
        isActionLoading: state.isActionLoading,
      ),
      if (ride.canDriverCancel)
        AppButton.danger(
          label: 'Annuler la course',
          isLoading: state.isActionLoading,
          onPressed: state.isActionLoading ? null : _confirmAndCancelRide,
        ),
      if (_canReport(ride.status))
        RideReportActionButton(
          onPressed: state.isActionLoading ? null : _openReportSheet,
        ),
    ];

    return _buildActionColumn(actions);
  }

  Widget? _buildChatAction(TrackingState state) {
    final ride = state.ride;
    if (ride == null || !ride.canUseChat) {
      return null;
    }
    return RideChatFab(
      unreadCount: state.unreadChatCount,
      onPressed: () => _openChat(),
    );
  }

  Future<void> _openReportSheet() async {
    final notifier = ref.read(trackingControllerProvider(_scope).notifier);
    await showRideReportBottomSheet(
      context,
      onSubmit: (draft) {
        return notifier.reportRide(
          reason: draft.reason,
          description: draft.description,
        );
      },
    );
  }

  Future<void> _openClientRatingSheet() async {
    final ride = ref.read(trackingControllerProvider(_scope)).ride;
    if (ride == null || !ride.canRateClient) {
      return;
    }
    final draft = await showRideRatingBottomSheet(
      context,
      title: 'Noter le client',
      submitLabel: 'Envoyer la note',
    );
    if (draft == null) {
      return;
    }

    await ref.read(trackingControllerProvider(_scope).notifier).rateClient(
          rating: draft.rating.toDouble(),
          comment: draft.comment,
        );
  }

  Future<void> _openChat() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RideChatScreen(
          scope: _scope,
          title: 'Client',
        ),
      ),
    );
  }

  Future<void> _openSupportChat() async {
    final result = await ref
        .read(supportContactServiceProvider)
        .openSupportChat(AppRole.driver);
    if (!mounted ||
        !_isUiMounted ||
        result.type != SupportContactResultType.failed) {
      return;
    }
    AppSnackbar.show(
      context,
      message: 'Impossible d ouvrir WhatsApp pour le moment.',
      tone: AppSnackbarTone.error,
    );
  }

  Future<void> _confirmAndCancelRide() async {
    final draft = await showRideCancellationBottomSheet(
      context,
      title: 'Pourquoi annuler cette course ?',
      confirmLabel: 'Confirmer l annulation',
      options: driverCancellationReasonOptions,
      reasonRequired: true,
    );
    if (!_isUiMounted || draft == null) {
      return;
    }
    await ref.read(trackingControllerProvider(_scope).notifier).cancelRide(
          reason: draft.reason,
          reasonCode: draft.reasonCode,
        );
  }

  List<Widget> _buildNavigationActions({
    required RideTrackingModel ride,
    required bool isActionLoading,
  }) {
    final navigationService = ref.read(navigationServiceProvider);
    final actions = <Widget>[];

    if (navigationService.canOpenPickupNavigation(ride.status)) {
      actions.add(
        AppButton.secondary(
          label: RideUiCopy.navigateToPickup,
          icon: Icons.person_pin_circle_outlined,
          onPressed: isActionLoading ? null : () => _openPickupNavigation(ride),
        ),
      );
    }

    if (navigationService.canOpenDestinationNavigation(ride.status)) {
      actions.add(
        AppButton.secondary(
          label: RideUiCopy.navigateToDestination,
          icon: Icons.flag_circle_outlined,
          onPressed:
              isActionLoading ? null : () => _openDestinationNavigation(ride),
        ),
      );
    }

    return actions;
  }

  Widget? _buildActionColumn(List<Widget> actions) {
    if (actions.isEmpty) {
      return null;
    }

    final spacedActions = <Widget>[];
    for (final action in actions) {
      if (spacedActions.isNotEmpty) {
        spacedActions.add(const SizedBox(height: 10));
      }
      spacedActions.add(action);
    }

    return Column(children: spacedActions);
  }

  Future<void> _openPickupNavigation(RideTrackingModel ride) async {
    final pickup = ride.pickupPosition;
    if (pickup == null) {
      _showNavigationFeedback(RideUiCopy.pickupNavigationUnavailable);
      return;
    }
    await _openNavigationForCoordinates(pickup);
  }

  Future<void> _openDestinationNavigation(RideTrackingModel ride) async {
    final destination = ride.dropoffPosition;
    if (destination == null) {
      _showNavigationFeedback(RideUiCopy.destinationNavigationUnavailable);
      return;
    }
    await _openNavigationForCoordinates(destination);
  }

  Future<void> _openNavigationForCoordinates(
    TrackingCoordinates coordinates,
  ) async {
    final navigationService = ref.read(navigationServiceProvider);
    final launchPlan = await navigationService.buildLaunchPlan(coordinates);
    if (!_isUiMounted) {
      return;
    }

    final selectedOption = await _selectNavigationOption(launchPlan);
    if (selectedOption == null) {
      return;
    }

    final launched =
        await navigationService.openWithOption(selectedOption, coordinates);
    if (!_isUiMounted || launched) {
      return;
    }

    _showNavigationFeedback(RideUiCopy.navigationOpenFailed);
  }

  Future<NavigationOption?> _selectNavigationOption(
    NavigationLaunchPlan launchPlan,
  ) async {
    if (!launchPlan.requiresUserChoice) {
      return launchPlan.defaultOption;
    }

    return showModalBottomSheet<NavigationOption>(
      context: context,
      builder: (sheetContext) => _NavigationChoiceSheet(
        options: launchPlan.options,
      ),
    );
  }

  void _showNavigationFeedback(String message) {
    if (!_isUiMounted) {
      return;
    }
    AppSnackbar.show(context, message: message);
  }

  bool _canReport(RideTrackingStatus status) {
    return status == RideTrackingStatus.accepted ||
        status == RideTrackingStatus.arrived ||
        status == RideTrackingStatus.started ||
        status == RideTrackingStatus.completed;
  }

  void _syncAutoRatingPrompt(
    RideTrackingModel? previousRide,
    RideTrackingModel? nextRide,
  ) {
    if (!_isUiMounted) {
      return;
    }
    if (nextRide == null || !nextRide.canRateClient) {
      _cancelAutoRatingPrompt();
      return;
    }

    if (previousRide?.id != nextRide.id) {
      _cancelAutoRatingPrompt();
    }
    if (_autoPromptedRideId == nextRide.id) {
      return;
    }

    final opensAt = nextRide.ratingWindowOpensAt;
    final closesAt = nextRide.ratingWindowClosesAt;
    if (opensAt == null || closesAt == null) {
      _cancelAutoRatingPrompt();
      return;
    }

    final now = DateTime.now();
    if (now.isAfter(closesAt)) {
      _cancelAutoRatingPrompt();
      return;
    }
    if (_ratingPromptRideId == nextRide.id && _ratingPromptTimer != null) {
      return;
    }

    final delay =
        opensAt.isAfter(now) ? opensAt.difference(now) : Duration.zero;
    _ratingPromptRideId = nextRide.id;
    _ratingPromptTimer = Timer(delay, () {
      if (!_isUiMounted) {
        return;
      }
      final latestRide = ref.read(trackingControllerProvider(_scope)).ride;
      if (latestRide == null ||
          latestRide.id != nextRide.id ||
          !latestRide.canRateClient) {
        _cancelAutoRatingPrompt();
        return;
      }
      _autoPromptedRideId = nextRide.id;
      _cancelAutoRatingPrompt();
      unawaited(_openClientRatingSheet());
    });
  }

  void _cancelAutoRatingPrompt() {
    _ratingPromptTimer?.cancel();
    _ratingPromptTimer = null;
    _ratingPromptRideId = null;
  }

  String? _recoveryMessage(TrackingState state) {
    if (state.errorMessage != null && state.errorMessage!.trim().isNotEmpty) {
      return _humanizeMessage(state.errorMessage!);
    }

    switch (state.connectionState) {
      case TrackingConnectionState.reconnecting:
        return RideUiCopy.reconnecting;
      case TrackingConnectionState.connecting:
        return 'On remet le trajet a jour...';
      case TrackingConnectionState.disconnected:
        return RideUiCopy.networkError;
      case TrackingConnectionState.connected:
        return null;
    }
  }

  bool _recoveryIsLoading(TrackingState state) {
    return state.connectionState == TrackingConnectionState.connecting ||
        state.connectionState == TrackingConnectionState.reconnecting ||
        state.isLoading;
  }

  String _humanizeMessage(String message) {
    final value = message.toLowerCase();
    if (value.contains('network') ||
        value.contains('connexion') ||
        value.contains('socket') ||
        value.contains('timeout')) {
      return RideUiCopy.networkError;
    }
    if (value.contains('gps')) {
      return RideUiCopy.gpsUnavailable;
    }
    if (value.contains('course annulee') ||
        value.contains('trajet a ete annule')) {
      return RideUiCopy.rideCancelled;
    }
    return message;
  }
}

class _NavigationChoiceSheet extends StatelessWidget {
  const _NavigationChoiceSheet({
    required this.options,
  });

  final List<NavigationOption> options;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              RideUiCopy.navigationChooserTitle,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final option in options)
            ListTile(
              leading: Icon(_iconForOption(option)),
              title: Text(option.label),
              onTap: () => Navigator.of(context).pop(option),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  IconData _iconForOption(NavigationOption option) {
    switch (option.app) {
      case NavigationApp.waze:
        return Icons.navigation_outlined;
      case NavigationApp.googleMaps:
      case NavigationApp.web:
        return Icons.map_outlined;
    }
  }
}
