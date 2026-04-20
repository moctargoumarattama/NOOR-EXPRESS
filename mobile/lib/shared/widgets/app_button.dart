import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

@immutable
class AppButtonThemeExtension extends ThemeExtension<AppButtonThemeExtension> {
  const AppButtonThemeExtension();

  @override
  ThemeExtension<AppButtonThemeExtension> copyWith() {
    return const AppButtonThemeExtension();
  }

  @override
  ThemeExtension<AppButtonThemeExtension> lerp(
    covariant ThemeExtension<AppButtonThemeExtension>? other,
    double t,
  ) {
    return const AppButtonThemeExtension();
  }
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
  }) : _variant = _AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
  }) : _variant = _AppButtonVariant.secondary;

  final String label;
  final VoidCallback? onPressed;
  final _AppButtonVariant _variant;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    );

    if (_variant == _AppButtonVariant.secondary) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        child: Text(label),
      );
    }

    return FilledButton(
      onPressed: onPressed,
      style: style.copyWith(
        backgroundColor: const WidgetStatePropertyAll(AppColors.emerald),
        foregroundColor: const WidgetStatePropertyAll(AppColors.pearl),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      child: Text(label),
    );
  }
}

enum _AppButtonVariant {
  primary,
  secondary,
}
