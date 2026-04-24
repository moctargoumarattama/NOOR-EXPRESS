import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum AppInlineFeedbackTone {
  info,
  success,
  warning,
  error,
}

class AppInlineFeedback extends StatelessWidget {
  const AppInlineFeedback({
    super.key,
    required this.message,
    this.tone = AppInlineFeedbackTone.info,
    this.isLoading = false,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final AppInlineFeedbackTone tone;
  final bool isLoading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(tone);
    final showAction = actionLabel != null && onAction != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.background,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: palette.foreground.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.1,
                        color: palette.foreground,
                      ),
                    )
                  : Icon(palette.icon, color: palette.foreground, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: palette.foreground,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                ),
                if (showAction) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: palette.foreground,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      actionLabel!,
                      style: const TextStyle(fontWeight: FontWeight.w800),
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

  _AppInlineFeedbackPalette _palette(AppInlineFeedbackTone tone) {
    switch (tone) {
      case AppInlineFeedbackTone.success:
        return const _AppInlineFeedbackPalette(
          background: Color(0xFFEAF7F1),
          border: Color(0xFFCFE9DC),
          foreground: AppColors.emerald,
          icon: Icons.check_circle_rounded,
        );
      case AppInlineFeedbackTone.warning:
        return const _AppInlineFeedbackPalette(
          background: Color(0xFFFFF6E6),
          border: Color(0xFFF3DEB2),
          foreground: Color(0xFF9B6A00),
          icon: Icons.wifi_tethering_error_rounded,
        );
      case AppInlineFeedbackTone.error:
        return const _AppInlineFeedbackPalette(
          background: Color(0xFFFFF1F0),
          border: Color(0xFFF2D0CD),
          foreground: AppColors.coral,
          icon: Icons.error_outline_rounded,
        );
      case AppInlineFeedbackTone.info:
        return const _AppInlineFeedbackPalette(
          background: Color(0xFFEFF4FF),
          border: Color(0xFFD7E4FF),
          foreground: Color(0xFF315DB7),
          icon: Icons.info_outline_rounded,
        );
    }
  }
}

class _AppInlineFeedbackPalette {
  const _AppInlineFeedbackPalette({
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color foreground;
  final IconData icon;
}
