import 'package:flutter/material.dart';

abstract final class AppColors {
  // Legacy palette kept for backward compatibility with existing screens.
  static const ink = Color(0xFF1A1A1A);
  static const midnight = Color(0xFF243126);
  static const cloud = Color(0xFFF8F8F8);
  static const pearl = Color(0xFFFFFFFF);
  static const stone = Color(0xFF757575);
  static const gold = Color(0xFFF5A623);
  static const emerald = Color(0xFF1B8A5A);
  static const coral = Color(0xFFE96962);
  static const border = Color(0xFFF0F0F0);
  static const shadow = Color(0x14000000);
  static const mint = Color(0xFFE8F5E9);

  // Noor Express modern palette.
  static const nigerOrange = Color(0xFFFF7A00);
  static const nigerOrangeDark = Color(0xFFE06800);
  static const nigerOrangeSoft = Color(0x12FF7A00);
  static const nigerOrangeBorder = Color(0x30FF7A00);

  static const nigerGreen = Color(0xFF009A44);
  static const nigerGreenSoft = Color(0x12009A44);
  static const nigerGreenBorder = Color(0x30009A44);

  static const backgroundPage = Color(0xFFF5F5F5);
  static const backgroundSubtle = Color(0xFFFAF9F7);
  static const overlay = Color(0x66000000);

  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF666666);
  static const textTertiary = Color(0xFFAAAAAA);

  static const error = Color(0xFFE53935);
  static const errorSoft = Color(0x12E53935);
  static const warning = Color(0xFFF59E0B);
  static const warningSoft = Color(0x12F59E0B);
  static const warningBorder = Color(0x30F59E0B);
  static const info = Color(0xFF1976D2);
  static const infoSoft = Color(0x121976D2);
  static const infoBorder = Color(0x301976D2);
}
