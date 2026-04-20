import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/app_routes.dart';
import '../../../../../shared/widgets/app_button.dart';
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
                widget.initialPayload!),
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
          AppSnackbar.show(context, message: next.toastMessage!);
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
          context.push(AppRoutes.driverMapWithRide(rideId));
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
    final ride = state.ride ?? _scope.initialRide;

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
                    'Proposer une offre',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Départ : ${ride?.pickup ?? 'En chargement...'}'),
                  const SizedBox(height: 10),
                  Text('Destination : ${ride?.dropoff ?? 'En chargement...'}'),
                  const SizedBox(height: 10),
                  Text('Prix client : ${_formatFcfa(ride?.clientPrice ?? 0)}'),
                  const SizedBox(height: 10),
                  Text(
                    ride?.distanceKm == null
                        ? 'Distance estimée indisponible'
                        : 'Distance estimée : ${ride!.distanceKm!.toStringAsFixed(1)} km',
                  ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.errorMessage!,
                      style: const TextStyle(color: Color(0xFFD64545)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
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
                        ? 'Offre envoyée, en attente de réponse...'
                        : 'Ton prix proposé',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _formatFcfa(state.submittedPrice ?? _proposedPrice),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: const Color(0xFF1B8A5A),
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 16),
                  if (!state.hasSubmittedOffer)
                    AppButton.secondary(
                      label: 'Modifier le prix',
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
            const SizedBox(height: 24),
            if (!state.hasSubmittedOffer) ...[
              AppButton(
                label: state.isSubmitting ? 'Envoi...' : 'Proposer ce prix',
                onPressed: state.isSubmitting || ride == null
                    ? null
                    : () {
                        final fallbackPrice = ride.clientPrice;
                        final targetPrice = _proposedPrice == 0
                            ? fallbackPrice
                            : _proposedPrice;
                        ref
                            .read(
                                negotiationControllerProvider(_scope).notifier)
                            .submitOffer(
                              targetPrice,
                            );
                      },
              ),
              const SizedBox(height: 14),
              AppButton.secondary(
                label: 'Ignorer',
                onPressed: state.isSubmitting ? null : context.pop,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatFcfa(double value) => '${value.round()} FCFA';
}
