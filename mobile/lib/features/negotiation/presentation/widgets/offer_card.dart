import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/app_surface_card.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_inline_feedback.dart';
import '../../../../../shared/widgets/status_badge.dart';
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
    this.compact = false,
  });

  final RideOfferModel offer;
  final VoidCallback onSelect;
  final VoidCallback? onReject;
  final bool isBusy;
  final bool isAccepting;
  final bool isRejecting;
  final bool isDisabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasActionInProgress = isBusy || isAccepting || isRejecting;
    final actionsDisabled = isDisabled || hasActionInProgress;
    final padding = compact ? 12.0 : 18.0;
    final avatarSize = compact ? 40.0 : 50.0;
    final hasDistance = _reliableDistanceKm != null;
    final plateLabel = _plateLabel;

    return AppSurfaceCard(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VehiclePhoto(
                photo: offer.vehiclePhoto,
                size: avatarSize,
              ),
              const SizedBox(width: 10),
              Expanded(child: _DriverInfo(offer: offer, compact: compact)),
              const SizedBox(width: 10),
              _PriceBlock(
                price: _formatFcfa(offer.proposedPrice),
                compact: compact,
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(
                icon: Icons.star_rounded,
                label: _ratingLabel,
              ),
              if (_completedRidesLabel != null)
                _InfoPill(
                  icon: Icons.route_rounded,
                  label: _completedRidesLabel!,
                ),
              if (offer.isDriverVerified)
                const _InfoPill(
                  icon: Icons.verified_rounded,
                  label: 'Verifie',
                ),
              if (hasDistance && compact)
                _InfoPill(
                  icon: Icons.near_me_rounded,
                  label: _distanceLabel,
                ),
              if (compact && plateLabel != null)
                _InfoPill(
                  icon: Icons.directions_car_filled_rounded,
                  label: plateLabel,
                ),
              if (!compact) StatusBadge(status: offer.status),
            ],
          ),
          if (!compact && hasDistance) ...[
            const SizedBox(height: 12),
            _MetricBox(
              label: 'Distance chauffeur',
              value: _distanceLabel,
              icon: Icons.near_me_rounded,
              compact: compact,
            ),
          ],
          if (!compact && plateLabel != null) ...[
            const SizedBox(height: 12),
            _PlateBadge(value: plateLabel),
          ],
          if (hasActionInProgress) ...[
            SizedBox(height: compact ? 10 : 14),
            AppInlineFeedback(
              message: isRejecting
                  ? 'Refus de cette offre...'
                  : 'Acceptation de cette offre...',
              tone: AppInlineFeedbackTone.info,
              isLoading: true,
            ),
          ],
          SizedBox(height: compact ? 10 : 16),
          if (compact)
            _CompactActionsRow(
              showReject: onReject != null,
              isAccepting: isAccepting || isBusy,
              isRejecting: isRejecting || (isBusy && !isAccepting),
              onAccept: actionsDisabled ? null : onSelect,
              onReject: actionsDisabled ? null : onReject,
            )
          else
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

  double? get _reliableDistanceKm {
    final distance = offer.driverDistanceKm;
    if (distance == null || !distance.isFinite || distance <= 0) {
      return null;
    }
    return distance;
  }

  String get _distanceLabel {
    return '${_reliableDistanceKm!.toStringAsFixed(1)} km';
  }

  String get _ratingLabel {
    if (offer.driverRating <= 0) {
      return 'Note a confirmer';
    }
    return offer.driverRating.toStringAsFixed(1);
  }

  String? get _completedRidesLabel {
    final count = offer.driverCompletedRides;
    if (count <= 0) {
      return null;
    }
    return count == 1 ? '1 course' : '$count courses';
  }

  String? get _plateLabel {
    final plate = offer.plateNumber?.trim();
    if (plate == null || plate.isEmpty) {
      return null;
    }
    return plate;
  }

  String _formatFcfa(double value) {
    final rounded = value.round();
    return '$rounded FCFA';
  }
}

class _DriverInfo extends StatelessWidget {
  const _DriverInfo({
    required this.offer,
    required this.compact,
  });

  final RideOfferModel offer;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          offer.driverName,
          style: (compact
                  ? Theme.of(context).textTheme.titleSmall
                  : Theme.of(context).textTheme.titleMedium)
              ?.copyWith(
            color: AppColors.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          offer.vehicleLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (compact
                  ? Theme.of(context).textTheme.bodySmall
                  : Theme.of(context).textTheme.bodyMedium)
              ?.copyWith(
            color: AppColors.stone,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _VehiclePhoto extends StatelessWidget {
  const _VehiclePhoto({
    required this.photo,
    required this.size,
  });

  final String? photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeVehiclePhoto(photo);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0x141B8A5A),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes == null
          ? const Icon(Icons.directions_car_rounded, color: AppColors.emerald)
          : Image.memory(
              bytes,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return const Icon(
                  Icons.directions_car_rounded,
                  color: AppColors.emerald,
                );
              },
            ),
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({
    required this.price,
    required this.compact,
  });

  final String price;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
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
            style: (compact
                    ? Theme.of(context).textTheme.titleSmall
                    : Theme.of(context).textTheme.titleMedium)
                ?.copyWith(
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
    required this.compact,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 72 : 86),
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEE9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.emerald, size: 18),
          SizedBox(height: compact ? 6 : 8),
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

class _CompactActionsRow extends StatelessWidget {
  const _CompactActionsRow({
    required this.showReject,
    required this.isAccepting,
    required this.isRejecting,
    required this.onAccept,
    required this.onReject,
  });

  final bool showReject;
  final bool isAccepting;
  final bool isRejecting;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showReject) ...[
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: onReject,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFDDE3DE)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isRejecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Refuser'),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: onAccept,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.emerald,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: isAccepting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.pearl,
                      ),
                    )
                  : const Text('Accepter'),
            ),
          ),
        ),
      ],
    );
  }
}

Uint8List? _decodeVehiclePhoto(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  try {
    return base64Decode(value);
  } on FormatException {
    return null;
  }
}
