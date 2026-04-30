import 'package:flutter/material.dart';

import '../models/route_result.dart';

class EtaOverlay extends StatelessWidget {
  const EtaOverlay({
    super.key,
    required this.route,
  });

  final RouteResult? route;

  @override
  Widget build(BuildContext context) {
    final currentRoute = route;
    if (currentRoute == null) {
      return const SizedBox.shrink();
    }
    if (!currentRoute.hasReliableMetrics) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        '${currentRoute.durationMinutes} min  ·  '
        '${currentRoute.distanceKm.toStringAsFixed(1)} km',
        style: const TextStyle(
          color: Color(0xFF1A1A1A),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
