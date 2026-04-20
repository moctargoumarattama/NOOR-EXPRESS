import 'package:flutter/material.dart';

import '../../data/models/driver_stats.dart';
import 'driver_stats_card.dart';

class DriverStatsSummary extends StatelessWidget {
  const DriverStatsSummary({super.key, required this.stats});

  final DriverStats? stats;

  @override
  Widget build(BuildContext context) {
    final data = stats;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DriverStatsCard(
                label: 'total',
                value: '${data?.totalRides ?? 0}',
                icon: Icons.route_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DriverStatsCard(
                label: 'terminees',
                value: '${data?.completed ?? 0}',
                icon: Icons.check_circle_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DriverStatsCard(
                label: 'net',
                value: '${(data?.totalNetEarnings ?? 0).toStringAsFixed(0)} F',
                icon: Icons.savings_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DriverStatsCard(
                label: 'note',
                value:
                    '⭐ ${(data?.averageRatingFromClients ?? 0).toStringAsFixed(1)}',
                icon: Icons.star_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class DriverStatsErrorCard extends StatelessWidget {
  const DriverStatsErrorCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'Impossible de charger les statistiques pour le moment.',
        style: TextStyle(color: Color(0xFFE53935)),
      ),
    );
  }
}
