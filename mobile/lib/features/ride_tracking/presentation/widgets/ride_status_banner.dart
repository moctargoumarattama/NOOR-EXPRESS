import 'package:flutter/material.dart';

import '../../data/models/ride_tracking_model.dart';

class RideStatusBanner extends StatelessWidget {
  const RideStatusBanner({
    super.key,
    required this.status,
    required this.title,
    required this.subtitle,
    this.showSpinner = false,
  });

  final RideTrackingStatus status;
  final String title;
  final String subtitle;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(status);

    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: palette.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: showSpinner
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.local_taxi_rounded,
                        color: Colors.white,
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _StatusPalette _palette(RideTrackingStatus status) {
    switch (status) {
      case RideTrackingStatus.pending:
        return const _StatusPalette(
          background: Color(0xFF1F2533),
          border: Color(0xFF2C3548),
          accent: Color(0xFFF5A623),
        );
      case RideTrackingStatus.accepted:
      case RideTrackingStatus.arrived:
        return const _StatusPalette(
          background: Color(0xFF172232),
          border: Color(0xFF1E334D),
          accent: Color(0xFF1B8A5A),
        );
      case RideTrackingStatus.started:
        return const _StatusPalette(
          background: Color(0xFF231E34),
          border: Color(0xFF3C3460),
          accent: Color(0xFF6E55D9),
        );
      default:
        return const _StatusPalette(
          background: Color(0xFF18281E),
          border: Color(0xFF274132),
          accent: Color(0xFF1B8A5A),
        );
    }
  }
}

class _StatusPalette {
  const _StatusPalette({
    required this.background,
    required this.border,
    required this.accent,
  });

  final Color background;
  final Color border;
  final Color accent;
}
