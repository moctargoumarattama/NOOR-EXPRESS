import 'package:flutter/material.dart';

import '../../data/models/ride_tracking_model.dart';

class DriverInfoCard extends StatelessWidget {
  const DriverInfoCard({
    super.key,
    required this.counterpart,
    required this.priceLabel,
    required this.roleLabel,
  });

  final TrackingCounterpartModel counterpart;
  final String priceLabel;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF1B8A5A).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                counterpart.avatarLabel,
                style: const TextStyle(
                  color: Color(0xFF1B8A5A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  counterpart.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  roleLabel,
                  style: const TextStyle(
                    color: Color(0xFF7A8598),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InfoPill(
                      icon: Icons.star_rounded,
                      label: counterpart.rating == null
                          ? 'Nouvelle note'
                          : counterpart.rating!.toStringAsFixed(1),
                    ),
                    if (counterpart.plateNumber != null &&
                        counterpart.plateNumber!.trim().isNotEmpty)
                      _InfoPill(
                        icon: Icons.directions_car_filled_rounded,
                        label: counterpart.plateNumber!,
                      ),
                    _InfoPill(
                      icon: Icons.payments_outlined,
                      label: priceLabel,
                    ),
                  ],
                ),
                if (counterpart.vehicleLabel != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    counterpart.vehicleLabel!,
                    style: const TextStyle(
                      color: Color(0xFF4B5568),
                      height: 1.4,
                    ),
                  ),
                ],
              ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF1B8A5A)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
