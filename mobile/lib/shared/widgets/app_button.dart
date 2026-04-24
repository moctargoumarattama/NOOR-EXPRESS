import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum AppButtonVariant {
  primary,
  secondary,
  danger,
}

@immutable
class AppButtonThemeExtension extends ThemeExtension<AppButtonThemeExtension> {
  const AppButtonThemeExtension({
    this.height = 56,
    this.borderRadius = 18,
    this.horizontalPadding = 20,
    this.labelStyle = const TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: 16,
      letterSpacing: 0.1,
    ),
  });

  final double height;
  final double borderRadius;
  final double horizontalPadding;
  final TextStyle labelStyle;

  @override
  AppButtonThemeExtension copyWith({
    double? height,
    double? borderRadius,
    double? horizontalPadding,
    TextStyle? labelStyle,
  }) {
    return AppButtonThemeExtension(
      height: height ?? this.height,
      borderRadius: borderRadius ?? this.borderRadius,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      labelStyle: labelStyle ?? this.labelStyle,
    );
  }

  @override
  AppButtonThemeExtension lerp(
    covariant ThemeExtension<AppButtonThemeExtension>? other,
    double t,
  ) {
    if (other is! AppButtonThemeExtension) {
      return this;
    }

    return AppButtonThemeExtension(
      height: lerpDouble(height, other.height, t) ?? height,
      borderRadius:
          lerpDouble(borderRadius, other.borderRadius, t) ?? borderRadius,
      horizontalPadding: lerpDouble(
            horizontalPadding,
            other.horizontalPadding,
            t,
          ) ??
          horizontalPadding,
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t) ?? labelStyle,
    );
  }
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  }) : variant = AppButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final buttonTheme =
        Theme.of(context).extension<AppButtonThemeExtension>() ??
            const AppButtonThemeExtension();
    final palette = _palette(variant);
    final effectiveOnPressed = isLoading ? null : onPressed;
    final borderRadius = BorderRadius.circular(buttonTheme.borderRadius);

    final child = _AppButtonContent(
      label: label,
      icon: icon,
      isLoading: isLoading,
      foregroundColor: palette.foreground,
    );

    if (variant == AppButtonVariant.secondary) {
      return SizedBox(
        width: double.infinity,
        height: buttonTheme.height,
        child: OutlinedButton(
          onPressed: effectiveOnPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: buttonTheme.horizontalPadding,
            ),
            minimumSize: Size.fromHeight(buttonTheme.height),
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
            textStyle: buttonTheme.labelStyle,
            side: BorderSide(color: palette.border),
          ).copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.disabled)
                  ? palette.disabledBackground
                  : palette.background;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.disabled)
                  ? palette.disabledForeground
                  : palette.foreground;
            }),
            side: WidgetStateProperty.resolveWith((states) {
              return BorderSide(
                color: states.contains(WidgetState.disabled)
                    ? palette.disabledBorder
                    : palette.border,
              );
            }),
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: buttonTheme.height,
      child: FilledButton(
        onPressed: effectiveOnPressed,
        style: FilledButton.styleFrom(
          padding:
              EdgeInsets.symmetric(horizontal: buttonTheme.horizontalPadding),
          minimumSize: Size.fromHeight(buttonTheme.height),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          textStyle: buttonTheme.labelStyle,
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.disabled)
                ? palette.disabledBackground
                : palette.background;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.disabled)
                ? palette.disabledForeground
                : palette.foreground;
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return palette.foreground.withValues(alpha: 0.08);
            }
            return null;
          }),
        ),
        child: child,
      ),
    );
  }

  _AppButtonPalette _palette(AppButtonVariant variant) {
    switch (variant) {
      case AppButtonVariant.secondary:
        return const _AppButtonPalette(
          background: AppColors.pearl,
          foreground: AppColors.ink,
          border: Color(0xFFDDE3DE),
          disabledBackground: Color(0xFFF7F8F8),
          disabledForeground: Color(0xFF9BA6A0),
          disabledBorder: Color(0xFFE6EBE7),
        );
      case AppButtonVariant.danger:
        return const _AppButtonPalette(
          background: Color(0xFFD94F4F),
          foreground: AppColors.pearl,
          border: Color(0xFFD94F4F),
          disabledBackground: Color(0xFFF3CACA),
          disabledForeground: Color(0xFFFDF7F7),
          disabledBorder: Color(0xFFF3CACA),
        );
      case AppButtonVariant.primary:
        return const _AppButtonPalette(
          background: AppColors.emerald,
          foreground: AppColors.pearl,
          border: AppColors.emerald,
          disabledBackground: Color(0xFFBFD7CD),
          disabledForeground: Color(0xFFF5FAF8),
          disabledBorder: Color(0xFFBFD7CD),
        );
    }
  }
}

class _AppButtonContent extends StatelessWidget {
  const _AppButtonContent({
    required this.label,
    required this.foregroundColor,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final Color foregroundColor;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final leading = isLoading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: foregroundColor,
            ),
          )
        : icon == null
            ? null
            : Icon(icon, size: 18, color: foregroundColor);

    return Stack(
      alignment: Alignment.center,
      children: [
        Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        if (leading != null)
          Positioned(
            left: 0,
            child: SizedBox(
              width: 22,
              height: 22,
              child: Center(child: leading),
            ),
          ),
      ],
    );
  }
}

class _AppButtonPalette {
  const _AppButtonPalette({
    required this.background,
    required this.foreground,
    required this.border,
    required this.disabledBackground,
    required this.disabledForeground,
    required this.disabledBorder,
  });

  final Color background;
  final Color foreground;
  final Color border;
  final Color disabledBackground;
  final Color disabledForeground;
  final Color disabledBorder;
}
