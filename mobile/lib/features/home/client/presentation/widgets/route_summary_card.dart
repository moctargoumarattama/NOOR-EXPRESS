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
    this.reliabilityMessage,
    this.compact = false,
  });

  final String pickupLabel;
  final String dropoffLabel;
  final double? distanceKm;
  final int? durationMinutes;
  final bool isRouteReliable;
  final double? recommendedPrice;
  final String? reliabilityMessage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final reliableDistance = isRouteReliable && _isReliableDistance(distanceKm);
    final reliableDuration =
        isRouteReliable && _isReliableDuration(durationMinutes);
    final reliablePrice = _isReliablePrice(recommendedPrice);

    if (compact) {
      return _CompactRouteSummaryCard(
        pickupLabel: pickupLabel,
        dropoffLabel: dropoffLabel,
        distanceKm: reliableDistance ? distanceKm : null,
        durationMinutes: reliableDuration ? durationMinutes : null,
        recommendedPrice: reliablePrice ? recommendedPrice : null,
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
          if (reliablePrice) ...[
            const SizedBox(height: 10),
            _RecommendedPriceTile(price: recommendedPrice!),
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
}

class _CompactRouteSummaryCard extends StatelessWidget {
  const _CompactRouteSummaryCard({
    required this.pickupLabel,
    required this.dropoffLabel,
    required this.distanceKm,
    required this.durationMinutes,
    required this.recommendedPrice,
    required this.reliabilityMessage,
  });

  final String pickupLabel;
  final String dropoffLabel;
  final double? distanceKm;
  final int? durationMinutes;
  final double? recommendedPrice;
  final String? reliabilityMessage;

  @override
  Widget build(BuildContext context) {
    final hasFullEstimate = distanceKm != null &&
        durationMinutes != null &&
        recommendedPrice != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEE9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.route_rounded,
                color: AppColors.emerald,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$pickupLabel \u2192 $dropoffLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasFullEstimate)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  '${distanceKm!.toStringAsFixed(1)} km \u2022 '
                  '$durationMinutes min',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  'Prix recommande : ${recommendedPrice!.round()} FCFA',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.emerald,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            )
          else
            Text(
              _compactReliabilityMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.stone,
                    fontWeight: FontWeight.w700,
                  ),
            ),
        ],
      ),
    );
  }

  String get _compactReliabilityMessage {
    final message = reliabilityMessage?.trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    return 'Estimation indisponible';
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
