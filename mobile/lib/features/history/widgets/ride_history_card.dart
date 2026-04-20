import 'package:flutter/material.dart';

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
  });

  final String pickup;
  final String dropoff;
  final double price;
  final String status;
  final DateTime createdAt;
  final String? vehicleLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _statusPalette(status);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_car_filled_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    vehicleLabel ?? 'Noor Express · Cash',
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
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatDate(createdAt),
                    style: const TextStyle(color: Color(0xFF757575)),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: palette.background,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    palette.label,
                    style: TextStyle(
                      color: palette.foreground,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.day}/${value.month}/${value.year} · ${hour}h$minute';
  }

  _StatusPalette _statusPalette(String status) {
    switch (status) {
      case 'completed':
        return const _StatusPalette(
            '✅ Terminee', Color(0xFFE8F5E9), Color(0xFF1B8A5A));
      case 'cancelled':
        return const _StatusPalette(
            '❌ Annulee', Color(0xFFFFEBEE), Color(0xFFE53935));
      case 'expired':
        return const _StatusPalette(
            '⏱️ Expiree', Color(0xFFECEFF3), Color(0xFF757575));
      default:
        return const _StatusPalette(
            'En cours', Color(0xFFFFF4E0), Color(0xFFF5A623));
    }
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
              Text(dropoff,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusPalette {
  const _StatusPalette(this.label, this.background, this.foreground);

  final String label;
  final Color background;
  final Color foreground;
}
