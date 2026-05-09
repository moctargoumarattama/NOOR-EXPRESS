import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/models/app_role.dart';
import '../../../../core/services/support_contact_service.dart';
import '../../../../shared/copy/ride_ui_copy.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../data/models/ride_tracking_model.dart';
import '../../domain/entities/tracking_state.dart';
import '../controllers/tracking_controller.dart';
import '../services/ride_share_service.dart';
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

class ClientTrackingScreen extends ConsumerStatefulWidget {
  const ClientTrackingScreen({
    super.key,
    this.rideId,
  });

  final int? rideId;

  @override
  ConsumerState<ClientTrackingScreen> createState() =>
      _ClientTrackingScreenState();
}

class _ClientTrackingScreenState extends ConsumerState<ClientTrackingScreen> {
  ProviderSubscription<TrackingState>? _subscription;
  Timer? _ratingPromptTimer;
  int? _ratingPromptRideId;
  int? _autoPromptedRideId;
  bool _isDisposed = false;

  TrackingControllerScope get _scope => TrackingControllerScope(
        mode: TrackingMode.client,
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

        AppSnackbar.show(
          context,
          message: _humanizeMessage(message),
          tone: _snackbarTone(message),
        );
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
    final pickup = ride?.pickupPosition ?? state.currentPosition;
    final statusPresentation = buildClientTrackingStatusPresentation(ride);
    final recoveryMessage = _recoveryMessage(state);

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: Stack(
        children: [
          Positioned.fill(
            child: MapView(
              status: ride?.status ?? RideTrackingStatus.pending,
              routePoints: state.routePoints,
              currentPosition: state.currentPosition,
              driverPosition: state.driverPosition,
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
                    Colors.black.withValues(alpha: 0.18),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.12),
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
                      context.go(AppRoutes.clientHome);
                    },
                  ),
                  if (recoveryMessage != null) ...[
                    const SizedBox(height: 14),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: TrackingRecoveryBanner(
                        key: ValueKey(
                          'client-recovery-${state.connectionState.name}-${state.errorMessage}',
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
                        'client-banner-${ride?.status.name ?? 'unknown'}-${statusPresentation.showSpinner}',
                      ),
                      status: ride?.status ?? RideTrackingStatus.unknown,
                      title: statusPresentation.title,
                      subtitle: statusPresentation.subtitle,
                      showSpinner: ride == null
                          ? state.isLoading
                          : statusPresentation.showSpinner,
                    ),
                  ),
                  if (ride == null && !state.isLoading) ...[
                    const SizedBox(height: 20),
                    const TrackingEmptyCard(
                      title: 'Aucune course active',
                      subtitle:
                          'Creez une course depuis l accueil client pour relancer le suivi live.',
                    ),
                  ],
                ],
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
                roleLabel: 'Votre chauffeur',
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

    if (ride.isArrived) {
      final isAlreadyReady = ride.passengerReadyAt != null;
      return AppButton(
        label: isAlreadyReady ? 'Chauffeur prevenu ✓' : 'Je suis pret',
        isLoading: state.isActionLoading,
        onPressed: state.isActionLoading || isAlreadyReady
            ? null
            : () {
                ref
                    .read(trackingControllerProvider(_scope).notifier)
                    .acknowledgePassengerReady();
              },
      );
    }

    if (ride.canRateDriver) {
      return AppButton(
        label: 'Noter le chauffeur',
        isLoading: state.isActionLoading,
        onPressed: state.isActionLoading ? null : _openRatingSheet,
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
      if (_canShareRide(ride.status))
        AppButton.secondary(
          label: RideUiCopy.shareRideAction,
          icon: Icons.share_outlined,
          isLoading: state.isActionLoading,
          onPressed: state.isActionLoading ? null : _shareRide,
        ),
      if (_canReport(ride.status))
        RideReportActionButton(
          onPressed: state.isActionLoading ? null : _openReportSheet,
        ),
      if (ride.canClientCancel)
        AppButton.danger(
          label: 'Annuler la course',
          isLoading: state.isActionLoading,
          onPressed: state.isActionLoading ? null : _confirmAndCancelRide,
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

  Future<void> _openRatingSheet() async {
    final ride = ref.read(trackingControllerProvider(_scope)).ride;
    if (ride == null || !ride.canRateDriver) {
      return;
    }
    final draft = await showDriverRatingBottomSheet(context);
    if (draft == null) {
      return;
    }

    await ref.read(trackingControllerProvider(_scope).notifier).rateDriver(
          rating: draft.rating.toDouble(),
          comment: draft.comment,
        );
  }

  Future<void> _openReportSheet() async {
    await showRideReportBottomSheet(
      context,
      onSubmit: (draft) {
        return ref.read(trackingControllerProvider(_scope).notifier).reportRide(
              reason: draft.reason,
              description: draft.description,
            );
      },
    );
  }

  void _syncAutoRatingPrompt(
    RideTrackingModel? previousRide,
    RideTrackingModel? nextRide,
  ) {
    if (!_isUiMounted) {
      return;
    }
    if (nextRide == null || !nextRide.canRateDriver) {
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
          !latestRide.canRateDriver) {
        _cancelAutoRatingPrompt();
        return;
      }
      _autoPromptedRideId = nextRide.id;
      _cancelAutoRatingPrompt();
      unawaited(_openRatingSheet());
    });
  }

  void _cancelAutoRatingPrompt() {
    _ratingPromptTimer?.cancel();
    _ratingPromptTimer = null;
    _ratingPromptRideId = null;
  }

  Future<void> _openChat() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RideChatScreen(
          scope: _scope,
          title: 'Votre chauffeur',
        ),
      ),
    );
  }

  Future<void> _openSupportChat() async {
    final result = await ref
        .read(supportContactServiceProvider)
        .openSupportChat(AppRole.client);
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
      title: 'Pourquoi annuler la course ?',
      confirmLabel: 'Confirmer l annulation',
      options: passengerCancellationReasonOptions,
      reasonRequired: false,
    );
    if (!_isUiMounted || draft == null) {
      return;
    }
    await ref.read(trackingControllerProvider(_scope).notifier).cancelRide(
          reason: draft.reason,
          reasonCode: draft.reasonCode,
        );
  }

  void _shareRide() {
    ref.read(trackingControllerProvider(_scope).notifier).shareRide();
  }

  bool _canShareRide(RideTrackingStatus status) {
    return ref.read(rideShareServiceProvider).canShareRide(status);
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

  bool _canReport(RideTrackingStatus status) {
    return status == RideTrackingStatus.accepted ||
        status == RideTrackingStatus.arrived ||
        status == RideTrackingStatus.started ||
        status == RideTrackingStatus.completed;
  }

  String? _recoveryMessage(TrackingState state) {
    if (state.errorMessage != null && state.errorMessage!.trim().isNotEmpty) {
      return _humanizeMessage(state.errorMessage!);
    }

    switch (state.connectionState) {
      case TrackingConnectionState.reconnecting:
        return RideUiCopy.reconnecting;
      case TrackingConnectionState.connecting:
        return 'On remet votre trajet a jour...';
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

  AppSnackbarTone _snackbarTone(String message) {
    final value = message.toLowerCase();
    if (value.contains('annulee')) {
      return AppSnackbarTone.error;
    }
    if (value.contains('terminee') || value.contains('merci')) {
      return AppSnackbarTone.success;
    }
    return AppSnackbarTone.info;
  }
}
