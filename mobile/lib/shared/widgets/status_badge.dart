import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label(status),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: palette.foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  _BadgePalette _palette(String value) {
    switch (value) {
      case 'accepted':
        return const _BadgePalette(
          background: Color(0xFFEFF4FF),
          foreground: Color(0xFF315DB7),
        );
      case 'arrived':
        return const _BadgePalette(
          background: Color(0xFFFFF6E3),
          foreground: Color(0xFF9B6A00),
        );
      case 'started':
        return const _BadgePalette(
          background: Color(0xFFF1EBFF),
          foreground: Color(0xFF6A42C2),
        );
      case 'completed':
        return const _BadgePalette(
          background: Color(0xFFE7F7F1),
          foreground: AppColors.emerald,
        );
      case 'cancelled':
      case 'expired':
        return const _BadgePalette(
          background: Color(0xFFFFF1F0),
          foreground: AppColors.coral,
        );
      default:
        return const _BadgePalette(
          background: Color(0xFFFFF6E3),
          foreground: Color(0xFF9B6A00),
        );
    }
  }

  String _label(String value) {
    switch (value) {
      case 'pending':
        return 'En attente';
      case 'accepted':
        return 'Acceptee';
      case 'arrived':
        return 'Arrivee';
      case 'started':
        return 'En cours';
      case 'completed':
        return 'Terminee';
      case 'cancelled':
        return 'Annulee';
      case 'expired':
        return 'Expiree';
      default:
        return value;
    }
  }
}

class _BadgePalette {
  const _BadgePalette({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}
