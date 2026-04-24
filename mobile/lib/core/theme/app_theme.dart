import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/widgets/app_button.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.manropeTextTheme();
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.emerald,
      onPrimary: AppColors.pearl,
      secondary: AppColors.gold,
      onSecondary: AppColors.ink,
      error: AppColors.coral,
      onError: AppColors.pearl,
      surface: AppColors.pearl,
      onSurface: AppColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.cloud,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.pearl,
        foregroundColor: AppColors.emerald,
        centerTitle: false,
        titleTextStyle: baseTextTheme.titleMedium?.copyWith(
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: baseTextTheme.copyWith(
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
          height: 1.05,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: AppColors.midnight,
          height: 1.45,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: AppColors.stone,
          height: 1.45,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.emerald, width: 2),
        ),
        hintStyle: const TextStyle(color: AppColors.stone),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emerald,
          foregroundColor: AppColors.pearl,
          minimumSize: const Size(double.infinity, 56),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.emerald,
          foregroundColor: AppColors.pearl,
          disabledBackgroundColor: const Color(0xFFBFD7CD),
          disabledForegroundColor: const Color(0xFFF5FAF8),
          minimumSize: const Size(double.infinity, 56),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.pearl,
          foregroundColor: AppColors.ink,
          disabledBackgroundColor: const Color(0xFFF7F8F8),
          disabledForegroundColor: const Color(0xFF9BA6A0),
          minimumSize: const Size(double.infinity, 56),
          side: const BorderSide(color: Color(0xFFDDE3DE)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.pearl,
        elevation: 0,
        shadowColor: AppColors.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide.none,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.emerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.pearl,
          fontWeight: FontWeight.w700,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.emerald,
      ),
      dividerColor: AppColors.border,
      chipTheme: const ChipThemeData(
        selectedColor: AppColors.emerald,
        disabledColor: AppColors.border,
        backgroundColor: AppColors.pearl,
        secondarySelectedColor: AppColors.emerald,
        labelStyle: TextStyle(
          color: AppColors.midnight,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: TextStyle(
          color: AppColors.pearl,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(color: AppColors.border),
        shape: StadiumBorder(),
      ),
      extensions: const [
        AppButtonThemeExtension(
          height: 56,
          borderRadius: 18,
          horizontalPadding: 20,
          labelStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}
