import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

class RouteSummaryCard extends StatelessWidget {
  const RouteSummaryCard({
    super.key,
    required this.pickupLabel,
    required this.dropoffLabel,
    this.distanceKm,
    this.durationMinutes,
    this.isRouteReliable = true,
    this.recommendedPrice,
    this.minimumPrice,
    this.maximumPrice,
    this.availableDriversCount,
    this.reliabilityMessage,
    this.compact = false,
  });

  final String pickupLabel;
  final String dropoffLabel;
  final double? distanceKm;
  final int? durationMinutes;
  final bool isRouteReliable;
  final double? recommendedPrice;
  final double? minimumPrice;
  final double? maximumPrice;
  final int? availableDriversCount;
  final String? reliabilityMessage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final reliableDistance = isRouteReliable && _isReliableDistance(distanceKm);
    final reliableDuration =
        isRouteReliable && _isReliableDuration(durationMinutes);
    final reliablePrice = _isReliablePrice(recommendedPrice);
    final reliableRange = _isReliablePriceRange(minimumPrice, maximumPrice);

    if (compact) {
      return _CompactRouteSummaryCard(
        pickupLabel: pickupLabel,
        dropoffLabel: dropoffLabel,
        distanceKm: reliableDistance ? distanceKm : null,
        durationMinutes: reliableDuration ? durationMinutes : null,
        recommendedPrice: reliablePrice ? recommendedPrice : null,
        minimumPrice: reliableRange ? minimumPrice : null,
        maximumPrice: reliableRange ? maximumPrice : null,
        availableDriversCount: _availabilityCount,
        reliabilityMessage: reliabilityMessage,
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8EEE9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RouteLine(
            pickupLabel: pickupLabel,
            dropoffLabel: dropoffLabel,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Distance',
                  value: reliableDistance
                      ? '${distanceKm!.toStringAsFixed(1)} km'
                      : '--',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Duree',
                  value: reliableDuration ? '$durationMinutes min' : '--',
                ),
              ),
            ],
          ),
          if (reliableRange) ...[
            const SizedBox(height: 10),
            _PriceRangeTile(
              minimumPrice: minimumPrice!,
              maximumPrice: maximumPrice!,
            ),
          ] else if (reliablePrice) ...[
            const SizedBox(height: 10),
            _RecommendedPriceTile(price: recommendedPrice!),
          ],
          if (_availabilityMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _availabilityMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _availabilityColor,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
          if (reliabilityMessage != null &&
              reliabilityMessage!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              reliabilityMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.stone,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isReliableDistance(double? value) {
    return value != null && value.isFinite && value > 0 && value < 1000;
  }

  bool _isReliableDuration(int? value) {
    return value != null && value > 0 && value < 1440;
  }

  bool _isReliablePrice(double? value) {
    return value != null && value.isFinite && value > 0 && value <= 500000;
  }

  bool _isReliablePriceRange(double? minimumPrice, double? maximumPrice) {
    return _isReliablePrice(minimumPrice) &&
        _isReliablePrice(maximumPrice) &&
        maximumPrice! >= minimumPrice!;
  }

  int? get _availabilityCount {
    final count = availableDriversCount;
    if (count == null || count < 0) {
      return null;
    }
    return count;
  }

  String? get _availabilityMessage {
    final count = _availabilityCount;
    if (count == null) {
      return null;
    }
    if (count == 0) {
      return 'Aucun chauffeur disponible pour l\'instant';
    }
    if (count == 1) {
      return '1 chauffeur disponible pres de vous';
    }
    return '$count chauffeurs disponibles pres de vous';
  }

  Color get _availabilityColor {
    if (_availabilityCount == 0) {
      return AppColors.coral;
    }
    return AppColors.emerald;
  }
}

class _CompactRouteSummaryCard extends StatelessWidget {
  const _CompactRouteSummaryCard({
    required this.pickupLabel,
    required this.dropoffLabel,
    required this.distanceKm,
    required this.durationMinutes,
    required this.recommendedPrice,
    required this.minimumPrice,
    required this.maximumPrice,
    required this.availableDriversCount,
    required this.reliabilityMessage,
  });

  final String pickupLabel;
  final String dropoffLabel;
  final double? distanceKm;
  final int? durationMinutes;
  final double? recommendedPrice;
  final double? minimumPrice;
  final double? maximumPrice;
  final int? availableDriversCount;
  final String? reliabilityMessage;

  @override
  Widget build(BuildContext context) {
    final hasMetrics = distanceKm != null && durationMinutes != null;
    final hasPriceRange = minimumPrice != null && maximumPrice != null;
    final hasRecommendedPrice = recommendedPrice != null;
    final hasEstimate = hasPriceRange || hasRecommendedPrice;
    final availabilityCount = availableDriversCount;
    final hasAvailability = availabilityCount != null && availabilityCount >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.pearl,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.nigerGreenSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: AppColors.nigerGreen,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$pickupLabel \u2192 $dropoffLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          if (hasMetrics || hasAvailability) ...[
            const SizedBox(height: 10),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (distanceKm != null)
                  _CompactMetricChip(
                    icon: Icons.straighten_rounded,
                    label: '${distanceKm!.toStringAsFixed(1)} km',
                  ),
                if (durationMinutes != null)
                  _CompactMetricChip(
                    icon: Icons.schedule_rounded,
                    label: '$durationMinutes min',
                  ),
                if (hasAvailability)
                  _CompactMetricChip(
                    icon: Icons.local_taxi_rounded,
                    label: availabilityCount == 0
                        ? '0 dispo'
                        : '$availabilityCount dispo',
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          if (hasEstimate)
            Text(
              hasPriceRange
                  ? 'Estimation : ${minimumPrice!.round()} - ${maximumPrice!.round()} FCFA'
                  : 'Estimation : ${recommendedPrice!.round()} FCFA',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.nigerOrangeDark,
                    fontWeight: FontWeight.w900,
                  ),
            )
          else
            Text(
              _compactReliabilityMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          if (_availabilityMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              _availabilityMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _availabilityColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  String get _compactReliabilityMessage {
    final message = reliabilityMessage?.trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    return 'Estimation en cours...';
  }

  String? get _availabilityMessage {
    final count = availableDriversCount;
    if (count == null || count < 0) {
      return null;
    }
    if (count == 0) {
      return 'Aucun chauffeur disponible pour l\'instant';
    }
    if (count == 1) {
      return '1 chauffeur disponible pres de vous';
    }
    return '$count chauffeurs disponibles pres de vous';
  }

  Color get _availabilityColor {
    if (availableDriversCount == 0) {
      return AppColors.error;
    }
    return AppColors.nigerGreen;
  }
}

class _CompactMetricChip extends StatelessWidget {
  const _CompactMetricChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.backgroundSubtle,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.pickupLabel,
    required this.dropoffLabel,
  });

  final String pickupLabel;
  final String dropoffLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const _RouteDot(color: AppColors.emerald),
            Container(
              width: 2,
              height: 38,
              margin: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const _RouteDot(color: AppColors.coral),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AddressLabel(label: 'Depart', value: pickupLabel),
              const SizedBox(height: 12),
              _AddressLabel(label: 'Arrivee', value: dropoffLabel),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddressLabel extends StatelessWidget {
  const _AddressLabel({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.stone,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _RecommendedPriceTile extends StatelessWidget {
  const _RecommendedPriceTile({required this.price});

  final double price;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.emerald,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'Prix recommande',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.emerald,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const Spacer(),
          Text(
            '${price.round()} FCFA',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.emerald,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _PriceRangeTile extends StatelessWidget {
  const _PriceRangeTile({
    required this.minimumPrice,
    required this.maximumPrice,
  });

  final double minimumPrice;
  final double maximumPrice;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.payments_rounded,
            color: AppColors.emerald,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'Fourchette estimee',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.emerald,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const Spacer(),
          Text(
            '${minimumPrice.round()} - ${maximumPrice.round()} FCFA',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.emerald,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _RouteDot extends StatelessWidget {
  const _RouteDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
