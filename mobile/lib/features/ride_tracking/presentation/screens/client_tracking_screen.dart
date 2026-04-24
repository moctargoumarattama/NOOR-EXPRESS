import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../shared/copy/ride_ui_copy.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../data/models/ride_tracking_model.dart';
import '../../domain/entities/tracking_state.dart';
import '../controllers/tracking_controller.dart';
import '../tracking_status_presenter.dart';
import '../widgets/bottom_ride_sheet.dart';
import '../widgets/map_view.dart';
import '../widgets/rating_bottom_sheet.dart';
import '../widgets/report_bottom_sheet.dart';
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

  TrackingControllerScope get _scope => TrackingControllerScope(
        mode: TrackingMode.client,
        rideId: widget.rideId,
      );

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual<TrackingState>(
      trackingControllerProvider(_scope),
      (previous, next) {
        final message = next.toastMessage;
        if (message == null || message == previous?.toastMessage || !mounted) {
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
                    Colors.black.withValues(alpha: 0.46),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.36),
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
                    etaMinutes: state.etaMinutes,
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
            BottomRideSheet(
              secondaryAction: _buildSecondaryActions(state),
              primaryAction: _buildPrimaryAction(state),
              child: RideDetailSection(
                ride: ride,
                counterpart: state.counterpart,
                roleLabel: 'Votre chauffeur',
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
      return AppButton(
        label: 'Je suis pret',
        isLoading: state.isActionLoading,
        onPressed: state.isActionLoading
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
      if (_canReport(ride.status))
        RideReportActionButton(
          onPressed: state.isActionLoading ? null : _openReportSheet,
        ),
      if (ride.canClientCancel) ...[
        if (_canReport(ride.status)) const SizedBox(height: 10),
        AppButton.danger(
          label: 'Annuler la course',
          isLoading: state.isActionLoading,
          onPressed: state.isActionLoading
              ? null
              : () {
                  ref
                      .read(trackingControllerProvider(_scope).notifier)
                      .cancelRide();
                },
        ),
      ],
    ];
    return actions.isEmpty ? null : Column(children: actions);
  }

  Future<void> _openRatingSheet() async {
    final draft = await showDriverRatingBottomSheet(context);
    if (draft == null) {
      return;
    }

    await ref.read(trackingControllerProvider(_scope).notifier).rateDriver(
          rating: draft.rating,
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
    if (value.contains('annul')) {
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
