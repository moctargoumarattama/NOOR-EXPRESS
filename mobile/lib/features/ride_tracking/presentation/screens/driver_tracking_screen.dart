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
import '../widgets/report_bottom_sheet.dart';
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

  TrackingControllerScope get _scope => TrackingControllerScope(
        mode: TrackingMode.driver,
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
        AppSnackbar.show(context, message: message);
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
    final pickup = ride?.pickupPosition;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: Stack(
        children: [
          Positioned.fill(
            child: MapView(
              status: ride?.status ?? RideTrackingStatus.accepted,
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
                    etaMinutes: state.etaMinutes,
                    onBack: context.pop,
                  ),
                  const SizedBox(height: 18),
                  RideStatusBanner(
                    status: ride?.status ?? RideTrackingStatus.accepted,
                    title: _titleFor(ride?.status),
                    subtitle: _subtitleFor(ride),
                  ),
                  if (ride == null && !state.isLoading) ...[
                    const SizedBox(height: 20),
                    const TrackingEmptyCard(
                      title: 'Aucune course active',
                      subtitle:
                          'Accepte une demande depuis l espace driver pour lancer le tracking live.',
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
                roleLabel: 'Client',
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
        onPressed: state.isActionLoading
            ? null
            : () {
                ref
                    .read(trackingControllerProvider(_scope).notifier)
                    .completeRide();
              },
      );
    }

    return null;
  }

  Widget? _buildSecondaryActions(TrackingState state) {
    final ride = state.ride;
    if (ride == null || !_canReport(ride.status)) {
      return null;
    }
    return RideReportActionButton(
      onPressed: state.isActionLoading ? null : _openReportSheet,
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

  String _titleFor(RideTrackingStatus? status) {
    switch (status) {
      case RideTrackingStatus.arrived:
        return 'En attente du passager';
      case RideTrackingStatus.started:
        return 'Navigation vers la destination';
      case RideTrackingStatus.completed:
        return 'Course terminee';
      default:
        return 'Direction le client';
    }
  }

  String _subtitleFor(RideTrackingModel? ride) {
    switch (ride?.status) {
      case RideTrackingStatus.arrived:
        return 'Le client peut maintenant confirmer qu il est pret a monter.';
      case RideTrackingStatus.started:
        return 'Suis le trajet jusqu a ${ride?.dropoffLocation ?? 'la destination'}.';
      case RideTrackingStatus.completed:
        return 'Encaissement cash et fin de mission.';
      default:
        return 'Approche du point de depart ${ride?.pickupLocation ?? ''}.';
    }
  }
}
