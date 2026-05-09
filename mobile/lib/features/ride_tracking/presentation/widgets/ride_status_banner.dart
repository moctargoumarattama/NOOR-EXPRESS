import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
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
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: Row(
            key: ValueKey('${status.name}|$showSpinner|$title|$subtitle'),
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.accent,
                  borderRadius: BorderRadius.circular(12),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _StatusPalette _palette(RideTrackingStatus status) {
    switch (status) {
      case RideTrackingStatus.pending:
      case RideTrackingStatus.offered:
        return const _StatusPalette(
          background: Color(0xFF1F2533),
          border: Color(0xFF2C3548),
          accent: AppColors.nigerOrange,
        );
      case RideTrackingStatus.accepted:
      case RideTrackingStatus.arrived:
        return const _StatusPalette(
          background: Color(0xFF172232),
          border: Color(0xFF1E334D),
          accent: AppColors.nigerGreen,
        );
      case RideTrackingStatus.started:
        return const _StatusPalette(
          background: Color(0xFF231E34),
          border: Color(0xFF3C3460),
          accent: Color(0xFF6E55D9),
        );
      case RideTrackingStatus.completed:
        return const _StatusPalette(
          background: Color(0xFF18281E),
          border: Color(0xFF274132),
          accent: AppColors.nigerGreen,
        );
      case RideTrackingStatus.cancelled:
      case RideTrackingStatus.expired:
        return const _StatusPalette(
          background: Color(0xFF2B1E22),
          border: Color(0xFF4F2D35),
          accent: Color(0xFFD64545),
        );
      case RideTrackingStatus.unknown:
        return const _StatusPalette(
          background: Color(0xFF20252E),
          border: Color(0xFF343B47),
          accent: Color(0xFF6B7280),
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
