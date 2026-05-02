import 'package:flutter/material.dart';

import '../../../shared/widgets/app_surface_card.dart';
import '../../../shared/widgets/status_badge.dart';

class RideHistoryCard extends StatelessWidget {
  const RideHistoryCard({
    super.key,
    required this.pickup,
    required this.dropoff,
    required this.price,
    required this.status,
    required this.createdAt,
    required this.onTap,
    this.vehicleLabel,
    this.details = const [],
    this.displayedAt,
  });

  final String pickup;
  final String dropoff;
  final double price;
  final String status;
  final DateTime createdAt;
  final String? vehicleLabel;
  final List<String> details;
  final DateTime? displayedAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: AppSurfaceCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_car_filled_rounded),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      vehicleLabel ?? 'Noor Express - Cash',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _RouteLine(pickup: pickup, dropoff: dropoff),
              const SizedBox(height: 16),
              Text(
                '${price.toStringAsFixed(0)} FCFA',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final detail in details)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      detail,
                      style: const TextStyle(
                        color: Color(0xFF5E6673),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDate(displayedAt ?? createdAt),
                      style: const TextStyle(color: Color(0xFF757575)),
                    ),
                  ),
                  StatusBadge(status: status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.day}/${value.month}/${value.year} - ${hour}h$minute';
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.pickup, required this.dropoff});

  final String pickup;
  final String dropoff;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Column(
          children: [
            Icon(Icons.trip_origin_rounded, size: 18, color: Color(0xFF1B8A5A)),
            SizedBox(height: 4),
            SizedBox(height: 24, child: VerticalDivider(width: 1)),
            Icon(Icons.flag_rounded, size: 18, color: Color(0xFFE53935)),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pickup, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 22),
              Text(
                dropoff,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
