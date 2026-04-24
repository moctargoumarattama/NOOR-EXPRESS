import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_inline_feedback.dart';
import '../../data/models/ride_offer_model.dart';

class OfferCard extends StatelessWidget {
  const OfferCard({
    super.key,
    required this.offer,
    required this.onSelect,
    this.onReject,
    this.isBusy = false,
    this.isAccepting = false,
    this.isRejecting = false,
    this.isDisabled = false,
  });

  final RideOfferModel offer;
  final VoidCallback onSelect;
  final VoidCallback? onReject;
  final bool isBusy;
  final bool isAccepting;
  final bool isRejecting;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final hasActionInProgress = isBusy || isAccepting || isRejecting;
    final actionsDisabled = isDisabled || hasActionInProgress;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0x141B8A5A),
                  borderRadius: BorderRadius.circular(18),
                ),
                child:
                    const Icon(Icons.person_rounded, color: AppColors.emerald),
              ),
              const SizedBox(width: 12),
              Expanded(child: _DriverInfo(offer: offer)),
              const SizedBox(width: 12),
              _PriceBlock(price: _formatFcfa(offer.proposedPrice)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricBox(
                  label: 'Distance chauffeur',
                  value: _distanceLabel,
                  icon: Icons.near_me_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricBox(
                  label: 'ETA',
                  value: _etaLabel,
                  icon: Icons.schedule_rounded,
                ),
              ),
            ],
          ),
          if (offer.plateNumber != null &&
              offer.plateNumber!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _PlateBadge(value: offer.plateNumber!.trim()),
          ],
          if (hasActionInProgress) ...[
            const SizedBox(height: 14),
            AppInlineFeedback(
              message: isRejecting
                  ? 'Refus de cette offre...'
                  : 'Acceptation de cette offre...',
              tone: AppInlineFeedbackTone.info,
              isLoading: true,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (onReject != null) ...[
                Expanded(
                  child: AppButton.secondary(
                    label: 'Refuser',
                    isLoading: isRejecting || (isBusy && !isAccepting),
                    onPressed: actionsDisabled ? null : onReject,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: AppButton(
                  label: 'Accepter',
                  isLoading: isAccepting || isBusy,
                  onPressed: actionsDisabled ? null : onSelect,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _distanceLabel {
    final distance = offer.driverDistanceKm;
    if (distance == null || !distance.isFinite || distance <= 0) {
      return 'Distance chauffeur indisponible';
    }
    return '${distance.toStringAsFixed(1)} km';
  }

  String get _etaLabel {
    final eta = offer.driverEtaMinutes;
    if (eta == null || eta <= 0) {
      return 'ETA indisponible';
    }
    return '$eta min';
  }

  String _formatFcfa(double value) {
    final rounded = value.round();
    return '$rounded FCFA';
  }
}

class _DriverInfo extends StatelessWidget {
  const _DriverInfo({required this.offer});

  final RideOfferModel offer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          offer.driverName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          offer.vehicleLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.stone,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoPill(
              icon: Icons.star_rounded,
              label: _ratingLabel,
            ),
            _StatusPill(status: offer.status),
          ],
        ),
      ],
    );
  }

  String get _ratingLabel {
    if (offer.driverRating <= 0) {
      return 'Note a confirmer';
    }
    return offer.driverRating.toStringAsFixed(1);
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.price});

  final String price;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'Prix chauffeur',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.emerald,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.emerald,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEE9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.emerald, size: 18),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.stone,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.emerald),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF315DB7),
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }

  String get _label {
    switch (status) {
      case 'accepted':
        return 'Acceptee';
      case 'rejected':
        return 'Refusee';
      default:
        return 'En attente';
    }
  }
}

class _PlateBadge extends StatelessWidget {
  const _PlateBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.directions_car_filled_rounded,
            color: Color(0xFF9B6A00),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF9B6A00),
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}
