import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noor_express_mobile/features/home/client/presentation/controllers/client_home_controller.dart';

import '../../../../../app/app_routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/copy/ride_ui_copy.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_inline_feedback.dart';
import '../../../../../shared/widgets/app_snackbar.dart';
import '../../../ride_tracking/presentation/widgets/report_bottom_sheet.dart';
import '../../data/models/ride_offer_model.dart';
import '../../domain/entities/negotiation_state.dart';
import '../controllers/negotiation_controller.dart';
import '../widgets/offer_card.dart';

enum _OfferAction {
  accept,
  reject,
}

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
  int? _busyOfferId;
  _OfferAction? _busyOfferAction;

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

        if ((previous?.isSubmitting ?? false) &&
            !next.isSubmitting &&
            _busyOfferId != null) {
          setState(() {
            _busyOfferId = null;
            _busyOfferAction = null;
          });
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
          context.go(AppRoutes.clientMapWithRide(rideId));
        }

        if (next.shouldCloseToHome && !(previous?.shouldCloseToHome ?? false)) {
          final notifier =
              ref.read(negotiationControllerProvider(_scope).notifier);
          notifier.consumeCloseAction();
          notifier.stop();
          await ref.read(clientHomeControllerProvider.notifier).loadRides();
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
    final statusMessage = _statusMessage(state);
    final hasOfferActionInProgress = _busyOfferId != null;
    final isCancelSubmitting = state.isSubmitting && !hasOfferActionInProgress;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F4),
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
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Choisissez votre chauffeur',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (statusMessage != null) ...[
                AppInlineFeedback(
                  message: statusMessage,
                  tone: _statusTone(state),
                  isLoading: _statusIsLoading(state),
                ),
                const SizedBox(height: 16),
              ],
              if (state.offers.isEmpty) ...[
                _WaitingPulse(
                  waiting: true,
                  priceLabel: _formatFcfa(ride?.clientPrice ?? 0),
                ),
                const SizedBox(height: 20),
              ] else ...[
                _OffersIntroCard(offersCount: state.offers.length),
                const SizedBox(height: 14),
              ],
              _RideSummaryCard(ride: ride),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _buildOffersSection(state),
              ),
              const SizedBox(height: 24),
              AppButton.danger(
                label: 'Arreter la recherche',
                isLoading: isCancelSubmitting,
                onPressed: state.isSubmitting || hasOfferActionInProgress
                    ? null
                    : _confirmAndCancelRide,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOffersSection(NegotiationState state) {
    if (state.isLoading && state.ride == null) {
      return const AppInlineFeedback(
        key: ValueKey('negotiation-loading'),
        message: RideUiCopy.refreshing,
        tone: AppInlineFeedbackTone.info,
        isLoading: true,
      );
    }

    if (state.offers.isEmpty) {
      return _WaitingOffersCard(
        key: const ValueKey('negotiation-waiting'),
        isSubmitting: state.isSubmitting,
      );
    }

    return ListView.separated(
      key: const ValueKey('negotiation-offers'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.offers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final offer = state.offers[index];
        final hasOfferActionInProgress = _busyOfferId != null;
        final isCurrentOffer = _busyOfferId == offer.offerId &&
            (state.isSubmitting || hasOfferActionInProgress);
        final busyAction = isCurrentOffer ? _busyOfferAction : null;
        return OfferCard(
          key: ValueKey('offer-${offer.offerId}'),
          offer: offer,
          isAccepting: busyAction == _OfferAction.accept,
          isRejecting: busyAction == _OfferAction.reject,
          isDisabled: (state.isSubmitting || hasOfferActionInProgress) &&
              !isCurrentOffer,
          onSelect: () {
            _markOfferBusy(offer.offerId, _OfferAction.accept);
            ref
                .read(
                  negotiationControllerProvider(_scope).notifier,
                )
                .acceptOffer(offer.offerId);
          },
          onReject: () {
            _markOfferBusy(offer.offerId, _OfferAction.reject);
            ref
                .read(
                  negotiationControllerProvider(_scope).notifier,
                )
                .rejectOffer(offer.offerId);
          },
        );
      },
    );
  }

  void _markOfferBusy(int offerId, _OfferAction action) {
    setState(() {
      _busyOfferId = offerId;
      _busyOfferAction = action;
    });
  }

  String _formatFcfa(double value) => '${value.round()} FCFA';

  String? _statusMessage(NegotiationState state) {
    if (state.errorMessage != null && state.errorMessage!.trim().isNotEmpty) {
      return _humanizeMessage(state.errorMessage!);
    }

    switch (state.connectionState) {
      case NegotiationConnectionState.reconnecting:
        return RideUiCopy.reconnecting;
      case NegotiationConnectionState.connecting:
        return 'On remet les propositions a jour...';
      case NegotiationConnectionState.disconnected:
        return RideUiCopy.negotiationRefreshHint;
      case NegotiationConnectionState.connected:
        if (state.offers.isEmpty) {
          return RideUiCopy.negotiationRefreshHint;
        }
        return null;
    }
  }

  AppInlineFeedbackTone _statusTone(NegotiationState state) {
    if (state.errorMessage != null && state.errorMessage!.trim().isNotEmpty) {
      return AppInlineFeedbackTone.error;
    }
    if (state.connectionState == NegotiationConnectionState.disconnected ||
        state.connectionState == NegotiationConnectionState.reconnecting) {
      return AppInlineFeedbackTone.warning;
    }
    return AppInlineFeedbackTone.info;
  }

  bool _statusIsLoading(NegotiationState state) {
    return state.connectionState == NegotiationConnectionState.connecting ||
        state.connectionState == NegotiationConnectionState.reconnecting ||
        (state.isLoading && state.offers.isEmpty);
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
    if (value.contains('course annulee') ||
        value.contains('trajet a ete annule')) {
      return RideUiCopy.rideCancelled;
    }
    if (value.contains('indisponible') && value.contains('chauffeur')) {
      return RideUiCopy.driverUnavailable;
    }
    return message;
  }

  Future<void> _confirmAndCancelRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la demande ?'),
        content: const Text(
          'Nous allons arreter la recherche. Vous pourrez relancer une demande '
          'quand vous voulez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuer'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD64545),
            ),
            child: const Text('Oui, arreter'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    final cancellationDraft = await showRideCancellationBottomSheet(
      context,
      title: 'Pourquoi annuler la demande ?',
      confirmLabel: 'Confirmer l annulation',
      options: passengerCancellationReasonOptions,
      reasonRequired: false,
    );
    if (!mounted) {
      return;
    }
    if (cancellationDraft == null) {
      return;
    }

    await ref
        .read(negotiationControllerProvider(_scope).notifier)
        .cancelRide(
          reason: cancellationDraft.reason,
          reasonCode: cancellationDraft.reasonCode,
        );
  }
}

class _RideSummaryCard extends StatelessWidget {
  const _RideSummaryCard({
    required this.ride,
  });

  final NegotiationRideModel? ride;

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
          Text(
            'Depart',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF6B7280),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(ride?.pickup ?? 'En chargement...'),
          const SizedBox(height: 10),
          Text(
            'Destination',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF6B7280),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(ride?.dropoff ?? 'En chargement...'),
          const SizedBox(height: 10),
          Text(
            'Prix propose : ${ride == null ? '--' : '${ride!.clientPrice.round()} FCFA'}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF1B8A5A),
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _OffersIntroCard extends StatelessWidget {
  const _OffersIntroCard({required this.offersCount});

  final int offersCount;

  @override
  Widget build(BuildContext context) {
    final label = offersCount == 1 ? 'offre recue' : 'offres recues';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.local_taxi_rounded,
              color: AppColors.emerald,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$offersCount $label. Comparez le prix, la distance et le chauffeur.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.emerald,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingOffersCard extends StatelessWidget {
  const _WaitingOffersCard({
    super.key,
    required this.isSubmitting,
  });

  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppInlineFeedback(
          message: isSubmitting
              ? 'On met votre demande a jour...'
              : 'On attend les reponses des chauffeurs.',
          tone: AppInlineFeedbackTone.info,
          isLoading: !isSubmitting,
        ),
        const SizedBox(height: 12),
        Text(
          RideUiCopy.negotiationRefreshHint,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.stone,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
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
                  colors: [Color(0xFFE8F5E9), Color(0x00E8F5E9)],
                ),
                border: Border.all(color: const Color(0x331B8A5A)),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Votre prix',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      priceLabel,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.emerald,
                            fontWeight: FontWeight.w900,
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
