import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/app_routes.dart';
import '../../../../../shared/copy/ride_ui_copy.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_inline_feedback.dart';
import '../../../../../shared/widgets/app_snackbar.dart';
import '../../data/models/ride_offer_model.dart';
import '../../domain/entities/negotiation_state.dart';
import '../controllers/negotiation_controller.dart';
import '../widgets/price_proposal_sheet.dart';

class DriverOfferScreen extends ConsumerStatefulWidget {
  const DriverOfferScreen({
    super.key,
    required this.rideId,
    this.initialPayload,
  });

  final int rideId;
  final Map<String, dynamic>? initialPayload;

  @override
  ConsumerState<DriverOfferScreen> createState() => _DriverOfferScreenState();
}

class _DriverOfferScreenState extends ConsumerState<DriverOfferScreen> {
  ProviderSubscription<NegotiationState>? _subscription;
  late double _proposedPrice;

  NegotiationScope get _scope => NegotiationScope(
        mode: NegotiationMode.driver,
        rideId: widget.rideId,
        initialRide: widget.initialPayload == null
            ? null
            : NegotiationRideModel.fromDriverNotificationJson(
                widget.initialPayload!,
              ),
      );

  @override
  void initState() {
    super.initState();
    _proposedPrice = _scope.initialRide?.clientPrice ?? 0;
    _subscription = ref.listenManual<NegotiationState>(
      negotiationControllerProvider(_scope),
      (previous, next) {
        if (!mounted) {
          return;
        }

        if (next.toastMessage != null &&
            next.toastMessage != previous?.toastMessage) {
          AppSnackbar.show(
            context,
            message: _humanizeMessage(next.toastMessage!),
          );
          ref
              .read(negotiationControllerProvider(_scope).notifier)
              .consumeToast();
        }

        if (next.navigateToTrackingRideId != null &&
            next.navigateToTrackingRideId !=
                previous?.navigateToTrackingRideId) {
          final rideId = next.navigateToTrackingRideId!;
          final notifier =
              ref.read(negotiationControllerProvider(_scope).notifier);
          notifier.consumeNavigation();
          notifier.stop();
          context.go(AppRoutes.driverMapWithRide(rideId));
        }

        if (next.shouldCloseToHome && !(previous?.shouldCloseToHome ?? false)) {
          final notifier =
              ref.read(negotiationControllerProvider(_scope).notifier);
          notifier.consumeCloseAction();
          notifier.stop();
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.driverHome);
          }
        }
      },
    );

    Future.microtask(() {
      ref.read(negotiationControllerProvider(_scope).notifier).start();
    });
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(negotiationControllerProvider(_scope));
    final ride = _mergeInitialDistance(state.ride, _scope.initialRide);
    final recoveryMessage = _recoveryMessage(state, ride);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1523),
      body: SafeArea(
        child: ListView(
          cacheExtent: 700,
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: context.pop,
                  icon:
                      const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Choisissez votre prix',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (recoveryMessage != null) ...[
              AppInlineFeedback(
                message: recoveryMessage,
                tone: _recoveryTone(state),
                isLoading: _recoveryLoading(state),
                actionLabel: _shouldShowManualRefresh(state, ride)
                    ? RideUiCopy.trackingRefreshAction
                    : null,
                onAction: _shouldShowManualRefresh(state, ride)
                    ? () => ref
                        .read(negotiationControllerProvider(_scope).notifier)
                        .refresh()
                    : null,
              ),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailLine(
                    label: 'Point de prise en charge',
                    value: ride?.pickup ?? 'En chargement...',
                  ),
                  const SizedBox(height: 10),
                  _DetailLine(
                    label: 'Destination',
                    value: ride?.dropoff ?? 'En chargement...',
                  ),
                  const SizedBox(height: 10),
                  _DetailLine(
                    label: 'Prix propose',
                    value: _formatFcfa(ride?.clientPrice ?? 0),
                    emphasize: true,
                  ),
                  const SizedBox(height: 10),
                  _DetailLine(
                    label: 'Distance chauffeur-client',
                    value: ride?.distanceKm == null
                        ? 'Indisponible'
                        : _distanceToClientLabel(ride!.distanceKm),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Container(
                key: ValueKey(
                  'driver-offer-${state.hasSubmittedOffer}-${state.isSubmitting}-${state.submittedPrice}',
                ),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0x14FFFFFF),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0x40FFFFFF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.hasSubmittedOffer
                          ? 'Proposition envoyee'
                          : 'Votre prix',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _formatFcfa(state.submittedPrice ?? _proposedPrice),
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: const Color(0xFF1B8A5A),
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const SizedBox(height: 16),
                    if (state.hasSubmittedOffer)
                      const AppInlineFeedback(
                        message:
                            'Votre proposition est bien envoyee. Nous vous prevenons des que le client repond.',
                        tone: AppInlineFeedbackTone.info,
                      )
                    else
                      AppButton.secondary(
                        label: 'Changer le prix',
                        onPressed: () async {
                          final nextPrice = await showPriceProposalSheet(
                            context,
                            initialPrice: _proposedPrice == 0
                                ? (ride?.clientPrice ?? 0)
                                : _proposedPrice,
                          );
                          if (nextPrice == null || !mounted) {
                            return;
                          }
                          setState(() {
                            _proposedPrice = nextPrice;
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (!state.hasSubmittedOffer) ...[
              AppButton(
                label: 'Envoyer ma proposition',
                isLoading: state.isSubmitting,
                onPressed: state.isSubmitting || ride == null
                    ? null
                    : () {
                        final fallbackPrice = ride.clientPrice;
                        final targetPrice = _proposedPrice == 0
                            ? fallbackPrice
                            : _proposedPrice;
                        ref
                            .read(
                              negotiationControllerProvider(_scope).notifier,
                            )
                            .submitOffer(targetPrice);
                      },
              ),
              const SizedBox(height: 14),
              AppButton.secondary(
                label: 'Pas maintenant',
                onPressed: state.isSubmitting ? null : context.pop,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatFcfa(double value) => '${value.round()} FCFA';

  NegotiationRideModel? _mergeInitialDistance(
    NegotiationRideModel? ride,
    NegotiationRideModel? initialRide,
  ) {
    if (ride == null) {
      return initialRide;
    }
    final initialDistance = initialRide?.distanceKm;
    if (ride.distanceKm != null || initialDistance == null) {
      return ride;
    }
    return ride.copyWith(distanceKm: initialDistance);
  }

  String _distanceToClientLabel(double? distanceKm) {
    if (distanceKm == null || !distanceKm.isFinite || distanceKm <= 0) {
      return 'Indisponible';
    }
    return 'A ${distanceKm.toStringAsFixed(1)} km de vous';
  }

  String? _recoveryMessage(
    NegotiationState state,
    NegotiationRideModel? ride,
  ) {
    if (state.errorMessage != null && state.errorMessage!.trim().isNotEmpty) {
      return _humanizeMessage(state.errorMessage!);
    }

    switch (state.connectionState) {
      case NegotiationConnectionState.reconnecting:
        return RideUiCopy.reconnecting;
      case NegotiationConnectionState.connecting:
        return 'On remet la demande a jour...';
      case NegotiationConnectionState.disconnected:
        return RideUiCopy.networkError;
      case NegotiationConnectionState.connected:
        if (ride == null) {
          return 'Cette demande revient a jour.';
        }
        return null;
    }
  }

  AppInlineFeedbackTone _recoveryTone(NegotiationState state) {
    if (state.errorMessage != null && state.errorMessage!.trim().isNotEmpty) {
      return AppInlineFeedbackTone.error;
    }
    if (state.connectionState == NegotiationConnectionState.disconnected ||
        state.connectionState == NegotiationConnectionState.reconnecting) {
      return AppInlineFeedbackTone.warning;
    }
    return AppInlineFeedbackTone.info;
  }

  bool _recoveryLoading(NegotiationState state) {
    return state.connectionState == NegotiationConnectionState.connecting ||
        state.connectionState == NegotiationConnectionState.reconnecting ||
        state.isLoading;
  }

  bool _shouldShowManualRefresh(
    NegotiationState state,
    NegotiationRideModel? ride,
  ) {
    return state.errorMessage != null ||
        state.connectionState != NegotiationConnectionState.connected ||
        ride == null;
  }

  String _humanizeMessage(String message) {
    final value = message.trim().toLowerCase();
    if (value.contains('network') ||
        value.contains('connexion') ||
        value.contains('socket') ||
        value.contains('timeout')) {
      return RideUiCopy.networkError;
    }
    if (value.contains('expire')) {
      return RideUiCopy.offerExpired;
    }
    if (value.contains('annul')) {
      return RideUiCopy.rideCancelled;
    }
    if (value.contains('indisponible') && value.contains('chauffeur')) {
      return RideUiCopy.driverUnavailable;
    }
    return message;
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: emphasize
              ? Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF1B8A5A),
                    fontWeight: FontWeight.w800,
                  )
              : null,
        ),
      ],
    );
  }
}
