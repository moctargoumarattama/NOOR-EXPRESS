import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../data/models/ride_tracking_model.dart';
import '../../domain/entities/tracking_state.dart';
import '../controllers/tracking_controller.dart';
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
          message: message,
          tone: _snackbarTone(message),
        );
        ref.read(trackingControllerProvider(_scope).notifier).consumeToast();
      },
    );

    Future.microtask(() {
      ref.read(trackingControllerProvider(_scope).notifier).start();
    });
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
                    onBack: context.pop,
                  ),
                  const SizedBox(height: 18),
                  RideStatusBanner(
                    status: ride?.status ?? RideTrackingStatus.pending,
                    title: _titleFor(ride?.status),
                    subtitle: _subtitleFor(ride),
                    showSpinner: ride == null || ride.isPending,
                  ),
                  if (ride == null && !state.isLoading) ...[
                    const SizedBox(height: 20),
                    const TrackingEmptyCard(
                      title: 'Aucune course active',
                      subtitle:
                          'Cree une course depuis l accueil client pour lancer le tracking live.',
                    ),
                  ],
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    TrackingErrorCard(message: state.errorMessage!),
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
        label: 'Noter le driver',
        onPressed: state.isActionLoading
            ? null
            : () {
                _openRatingSheet();
              },
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
        AppButton.secondary(
          label: 'Annuler la course',
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

  AppSnackbarTone _snackbarTone(String message) {
    if (message.contains('annulee')) {
      return AppSnackbarTone.error;
    }
    if (message.contains('terminee') || message.contains('Merci')) {
      return AppSnackbarTone.success;
    }
    return AppSnackbarTone.info;
  }

  String _titleFor(RideTrackingStatus? status) {
    switch (status) {
      case RideTrackingStatus.accepted:
        return 'Driver accepte, il arrive';
      case RideTrackingStatus.arrived:
        return 'Votre driver est arrive';
      case RideTrackingStatus.started:
        return 'Course en cours';
      case RideTrackingStatus.completed:
        return 'Fin de course';
      default:
        return 'Recherche d un driver';
    }
  }

  String _subtitleFor(RideTrackingModel? ride) {
    switch (ride?.status) {
      case RideTrackingStatus.accepted:
        return 'Le chauffeur se dirige vers votre point de depart en direct.';
      case RideTrackingStatus.arrived:
        return 'Le chauffeur vous attend au point de prise en charge.';
      case RideTrackingStatus.started:
        return 'Le trajet vers ${ride?.dropoffLocation ?? 'la destination'} est lance.';
      case RideTrackingStatus.completed:
        return 'Le paiement cash se regle directement avec le chauffeur.';
      default:
        return 'Noor Express cherche le meilleur chauffeur disponible a Niamey.';
    }
  }
}
