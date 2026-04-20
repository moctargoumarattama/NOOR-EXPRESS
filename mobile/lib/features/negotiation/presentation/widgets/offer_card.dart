import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../data/models/ride_offer_model.dart';

class OfferCard extends StatelessWidget {
  const OfferCard({
    super.key,
    required this.offer,
    required this.onSelect,
    this.onReject,
    this.isBusy = false,
  });

  final RideOfferModel offer;
  final VoidCallback onSelect;
  final VoidCallback? onReject;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0x141B8A5A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.person_rounded, color: AppColors.emerald),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.driverName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${offer.driverRating.toStringAsFixed(1)} ★ • ${offer.vehicleLabel}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Text(
                _formatFcfa(offer.proposedPrice),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF1B8A5A),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (offer.driverDistanceKm != null)
            Text(
              'Driver à ${offer.driverDistanceKm!.toStringAsFixed(1)} km',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.stone,
              ),
            ),
          if (offer.plateNumber != null && offer.plateNumber!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Plaque : ${offer.plateNumber}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (onReject != null) ...[
                Expanded(
                  child: AppButton.secondary(
                    label: 'Refuser',
                    onPressed: isBusy ? null : onReject,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: AppButton(
                  label: isBusy ? 'Chargement...' : 'Choisir ce driver',
                  onPressed: isBusy ? null : onSelect,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatFcfa(double value) {
    final rounded = value.round();
    return '$rounded FCFA';
  }
}
