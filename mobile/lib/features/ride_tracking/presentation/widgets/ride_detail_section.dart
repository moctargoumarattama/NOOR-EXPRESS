import 'package:flutter/material.dart';

import '../../data/models/ride_tracking_model.dart';
import 'driver_info_card.dart';

class RideDetailSection extends StatelessWidget {
  const RideDetailSection({
    super.key,
    required this.ride,
    required this.roleLabel,
    this.counterpart,
    this.distanceRemainingKm,
    this.statusLabel,
  });

  final RideTrackingModel ride;
  final TrackingCounterpartModel? counterpart;
  final String roleLabel;
  final double? distanceRemainingKm;
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (counterpart != null)
          DriverInfoCard(
            counterpart: counterpart!,
            roleLabel: roleLabel,
            priceLabel: '${ride.displayedPrice.toStringAsFixed(0)} FCFA',
          ),
        if (counterpart != null) const SizedBox(height: 18),
        RideDetailRow(label: 'Depart', value: ride.pickupLocation),
        const SizedBox(height: 10),
        RideDetailRow(label: 'Destination', value: ride.dropoffLocation),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _RideFactChip(
              icon: Icons.payments_outlined,
              label: 'Prix accepte',
              value: '${ride.displayedPrice.toStringAsFixed(0)} FCFA',
            ),
            if (statusLabel != null)
              _RideFactChip(
                icon: Icons.route_rounded,
                label: 'Statut',
                value: statusLabel!,
              ),
            if (distanceRemainingKm != null)
              _RideFactChip(
                icon: Icons.social_distance_rounded,
                label: 'Restant',
                value: '${distanceRemainingKm!.toStringAsFixed(1)} km',
              ),
          ],
        ),
      ],
    );
  }
}

class RideDetailRow extends StatelessWidget {
  const RideDetailRow({
    super.key,
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
          style: const TextStyle(
            color: Color(0xFF7A8598),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _RideFactChip extends StatelessWidget {
  const _RideFactChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF1B8A5A)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF7A8598),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
