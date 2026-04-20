import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noor_express_mobile/features/home/client/presentation/controllers/client_home_controller.dart';

import '../../../../../app/app_routes.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_snackbar.dart';
import '../../data/models/ride_offer_model.dart';
import '../../domain/entities/negotiation_state.dart';
import '../controllers/negotiation_controller.dart';
import '../widgets/offer_card.dart';

class ClientNegotiationScreen extends ConsumerStatefulWidget {
  const ClientNegotiationScreen({
    super.key,
    required this.rideId,
  });

  final int rideId;

  @override
  ConsumerState<ClientNegotiationScreen> createState() =>
      _ClientNegotiationScreenState();
}

class _ClientNegotiationScreenState
    extends ConsumerState<ClientNegotiationScreen> {
  ProviderSubscription<NegotiationState>? _subscription;

  NegotiationScope get _scope => NegotiationScope(
        mode: NegotiationMode.client,
        rideId: widget.rideId,
      );

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual<NegotiationState>(
      negotiationControllerProvider(_scope),
      (previous, next) async {
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
          context.push(AppRoutes.clientMapWithRide(rideId));
        }

        if (next.shouldCloseToHome && !(previous?.shouldCloseToHome ?? false)) {
          final notifier =
              ref.read(negotiationControllerProvider(_scope).notifier);
          notifier.consumeCloseAction();
          notifier.stop();
          await ref
              .read(clientHomeControllerProvider.notifier)
              .refreshRideStatus(
                rideId: widget.rideId,
                status: 'cancelled',
              );
          if (!mounted) {
            return;
          }
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.clientHome);
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
    final ride = state.ride;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1523),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref
              .read(negotiationControllerProvider(_scope).notifier)
              .refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            cacheExtent: 900,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: context.pop,
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Négociation en cours',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                              ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _WaitingPulse(
                waiting: state.offers.isEmpty,
                priceLabel: _formatFcfa(ride?.clientPrice ?? 0),
              ),
              const SizedBox(height: 20),
              _RideSummaryCard(ride: ride, errorMessage: state.errorMessage),
              const SizedBox(height: 20),
              if (state.isLoading && ride == null)
                const Center(child: CircularProgressIndicator())
              else if (state.offers.isEmpty)
                _WaitingOffersCard(isSubmitting: state.isSubmitting)
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.offers.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final offer = state.offers[index];
                    return OfferCard(
                      key: ValueKey('offer-${offer.offerId}'),
                      offer: offer,
                      isBusy: state.isSubmitting,
                      onSelect: () {
                        ref
                            .read(
                                negotiationControllerProvider(_scope).notifier)
                            .acceptOffer(offer.offerId);
                      },
                      onReject: () {
                        ref
                            .read(
                                negotiationControllerProvider(_scope).notifier)
                            .rejectOffer(offer.offerId);
                      },
                    );
                  },
                ),
              const SizedBox(height: 24),
              AppButton.secondary(
                label:
                    state.isSubmitting ? 'Annulation...' : 'Annuler la demande',
                onPressed: state.isSubmitting ? null : _confirmAndCancelRide,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFcfa(double value) => '${value.round()} FCFA';

  Future<void> _confirmAndCancelRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la demande ?'),
        content: const Text(
          'La recherche de chauffeur sera arretee. Vous pourrez refaire une '
          'demande juste apres.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuer a chercher'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD64545),
            ),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    final reason = await _askCancellationReason();
    if (!mounted) {
      return;
    }

    await ref
        .read(negotiationControllerProvider(_scope).notifier)
        .cancelRide(reason: reason);
  }

  Future<String?> _askCancellationReason() async {
    final controller = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pourquoi annuler ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'La raison est optionnelle. Elle nous aide seulement a ameliorer '
              'le service.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Ex: trop long, erreur de destination...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Passer'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Envoyer et annuler'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }
}

class _RideSummaryCard extends StatelessWidget {
  const _RideSummaryCard({
    required this.ride,
    required this.errorMessage,
  });

  final NegotiationRideModel? ride;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Départ : ${ride?.pickup ?? 'En chargement...'}'),
          const SizedBox(height: 8),
          Text('Destination : ${ride?.dropoff ?? 'En chargement...'}'),
          const SizedBox(height: 8),
          Text(
              'Prix proposé : ${ride == null ? '--' : '${ride!.clientPrice.round()} FCFA'}'),
          if (errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(errorMessage!,
                style: const TextStyle(color: Color(0xFFD64545))),
          ],
        ],
      ),
    );
  }
}

class _WaitingOffersCard extends StatelessWidget {
  const _WaitingOffersCard({required this.isSubmitting});

  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x141B8A5A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x401B8A5A)),
      ),
      child: Text(
        isSubmitting
            ? 'Action en cours...'
            : 'En attente des propositions des drivers...',
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: Colors.white),
      ),
    );
  }
}

class _WaitingPulse extends StatelessWidget {
  const _WaitingPulse({
    required this.waiting,
    required this.priceLabel,
  });

  final bool waiting;
  final String priceLabel;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: waiting ? 1.12 : 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      builder: (context, value, _) {
        return Center(
          child: Transform.scale(
            scale: value,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0x441B8A5A), Color(0x100D1523)],
                ),
                border: Border.all(color: const Color(0x66F5A623)),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Niamey',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      priceLabel,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: const Color(0xFFF5A623),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
