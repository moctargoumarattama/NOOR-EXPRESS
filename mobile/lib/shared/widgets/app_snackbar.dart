import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum AppSnackbarTone {
  info,
  success,
  error,
}

class AppSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    AppSnackbarTone tone = AppSnackbarTone.info,
  }) {
    final palette = _palette(tone);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.all(16),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(palette.icon, color: palette.foreground),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette.foreground,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  static _SnackbarPalette _palette(AppSnackbarTone tone) {
    switch (tone) {
      case AppSnackbarTone.success:
        return const _SnackbarPalette(
          background: Color(0xFFE7F7F1),
          foreground: AppColors.emerald,
          icon: Icons.check_circle_rounded,
        );
      case AppSnackbarTone.error:
        return const _SnackbarPalette(
          background: Color(0xFFFFF1F0),
          foreground: AppColors.coral,
          icon: Icons.error_rounded,
        );
      case AppSnackbarTone.info:
        return const _SnackbarPalette(
          background: AppColors.ink,
          foreground: AppColors.pearl,
          icon: Icons.notifications_active_rounded,
        );
    }
  }
}

class _SnackbarPalette {
  const _SnackbarPalette({
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
}
