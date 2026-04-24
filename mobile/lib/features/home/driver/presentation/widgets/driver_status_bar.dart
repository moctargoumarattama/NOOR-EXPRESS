import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/noor_logo.dart';

class DriverStatusBar extends StatelessWidget {
  const DriverStatusBar({
    super.key,
    required this.status,
    required this.onMenuTap,
  });

  final String status;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(status);
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: onMenuTap,
                icon: const Icon(Icons.menu_rounded),
              ),
              const Expanded(
                child: Center(
                  child: NoorLogo.compact(width: 112),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: palette.background,
                  border: Border.all(color: palette.border),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: palette.foreground,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      palette.label,
                      style: TextStyle(
                        color: palette.foreground,
                        fontWeight: FontWeight.w900,
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

  _StatusPalette _palette(String value) {
    switch (value) {
      case 'busy':
        return const _StatusPalette(
          label: 'En course',
          background: Color(0xFFFFF6E3),
          foreground: Color(0xFF9B6A00),
          border: Color(0xFFF3DEB2),
        );
      case 'online':
        return const _StatusPalette(
          label: 'Disponible',
          background: Color(0xFFEAF7F1),
          foreground: AppColors.emerald,
          border: Color(0xFFCFE9DC),
        );
      default:
        return const _StatusPalette(
          label: 'En pause',
          background: Color(0xFFFFF1F0),
          foreground: AppColors.coral,
          border: Color(0xFFF2D0CD),
        );
    }
  }
}

class _StatusPalette {
  const _StatusPalette({
    required this.label,
    required this.background,
    required this.foreground,
    required this.border,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color border;
}
