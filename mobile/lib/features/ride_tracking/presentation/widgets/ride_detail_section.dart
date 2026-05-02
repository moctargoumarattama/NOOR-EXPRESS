import 'package:flutter/material.dart';

import '../../data/models/ride_tracking_model.dart';
import '../../../../shared/widgets/app_surface_card.dart';
import '../../../../shared/widgets/status_badge.dart';
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
        if (ride.isCompleted) ...[
          _RideReceiptCard(ride: ride),
          const SizedBox(height: 18),
        ],
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
            if (ride.isCompleted &&
                ride.distanceKm != null &&
                ride.distanceKm! > 0)
              _RideFactChip(
                icon: Icons.map_rounded,
                label: 'Distance',
                value: '${ride.distanceKm!.toStringAsFixed(1)} km',
              ),
            if (ride.isCompleted &&
                ride.durationMinutes != null &&
                ride.durationMinutes! > 0)
              _RideFactChip(
                icon: Icons.schedule_rounded,
                label: 'Duree',
                value: '${ride.durationMinutes} min',
              ),
            if (ride.isCompleted &&
                ride.platformCommission != null &&
                ride.platformCommission! > 0)
              _RideFactChip(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Commission',
                value: '${ride.platformCommission!.toStringAsFixed(0)} FCFA',
              ),
            if (ride.isCompleted &&
                ride.driverNetEarnings != null &&
                ride.driverNetEarnings! > 0)
              _RideFactChip(
                icon: Icons.savings_rounded,
                label: 'Net chauffeur',
                value: '${ride.driverNetEarnings!.toStringAsFixed(0)} FCFA',
              ),
          ],
        ),
      ],
    );
  }
}

class _RideReceiptCard extends StatelessWidget {
  const _RideReceiptCard({required this.ride});

  final RideTrackingModel ride;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF4FBF7),
              Color(0xFFFFFFFF),
            ],
          ),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0x141B8A5A),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Color(0xFF1B8A5A),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recu de course',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Paiement et trajet confirmes',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const StatusBadge(status: 'completed'),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              '${ride.displayedPrice.toStringAsFixed(0)} FCFA',
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _receiptMeta,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (ride.distanceKm != null && ride.distanceKm! > 0)
                  _ReceiptPill(
                    icon: Icons.map_rounded,
                    label: '${ride.distanceKm!.toStringAsFixed(1)} km',
                  ),
                if (ride.durationMinutes != null && ride.durationMinutes! > 0)
                  _ReceiptPill(
                    icon: Icons.schedule_rounded,
                    label: '${ride.durationMinutes} min',
                  ),
                if (ride.platformCommission != null &&
                    ride.platformCommission! > 0)
                  _ReceiptPill(
                    icon: Icons.account_balance_wallet_rounded,
                    label:
                        'Commission ${ride.platformCommission!.toStringAsFixed(0)} FCFA',
                  ),
                if (ride.driverNetEarnings != null &&
                    ride.driverNetEarnings! > 0)
                  _ReceiptPill(
                    icon: Icons.savings_rounded,
                    label:
                        'Net ${ride.driverNetEarnings!.toStringAsFixed(0)} FCFA',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _receiptMeta {
    final date = ride.completedAt ?? ride.createdAt;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return 'Course #${ride.id} - ${date.day}/${date.month}/${date.year} a ${hour}h$minute';
  }
}

class _ReceiptPill extends StatelessWidget {
  const _ReceiptPill({
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
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF1B8A5A)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
