import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum NotificationCardTone {
  info,
  success,
  warning,
  error,
}

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.title,
    required this.message,
    this.tone = NotificationCardTone.info,
  });

  final String title;
  final String message;
  final NotificationCardTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(tone);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.foreground.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(palette.icon, color: palette.foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: palette.foreground,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: palette.foreground.withValues(alpha: 0.9),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _NotificationPalette _palette(NotificationCardTone tone) {
    switch (tone) {
      case NotificationCardTone.success:
        return const _NotificationPalette(
          background: Color(0xFFE7F7F1),
          foreground: AppColors.emerald,
          icon: Icons.check_circle_rounded,
        );
      case NotificationCardTone.warning:
        return const _NotificationPalette(
          background: Color(0xFFFFF6E3),
          foreground: Color(0xFF9B6A00),
          icon: Icons.local_taxi_rounded,
        );
      case NotificationCardTone.error:
        return const _NotificationPalette(
          background: Color(0xFFFFF1F0),
          foreground: AppColors.coral,
          icon: Icons.error_rounded,
        );
      case NotificationCardTone.info:
        return const _NotificationPalette(
          background: Color(0xFFEFF4FF),
          foreground: Color(0xFF315DB7),
          icon: Icons.notifications_rounded,
        );
    }
  }
}

class _NotificationPalette {
  const _NotificationPalette({
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
}
