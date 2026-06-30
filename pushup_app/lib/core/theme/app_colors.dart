import 'package:flutter/material.dart';

/// KINETIC AI design system color tokens extracted from Stitch mockups.
class AppColors {
  AppColors._();

  // ── Brand Primary (Neon Green) ──
  static const Color primary = Color(0xFF8EFF71);
  static const Color primaryDim = Color(0xFF2BE800);
  static const Color primaryContainer = Color(0xFF2FF801);
  static const Color onPrimary = Color(0xFF0D6100);
  static const Color onPrimaryContainer = Color(0xFF0B5800);

  // ── Brand Secondary (Cyan) ──
  static const Color secondary = Color(0xFF00F1FD);
  static const Color secondaryDim = Color(0xFF00E2ED);
  static const Color secondaryContainer = Color(0xFF00696F);
  static const Color onSecondary = Color(0xFF00565A);

  // ── Tertiary ──
  static const Color tertiary = Color(0xFF88F6FF);
  static const Color tertiaryContainer = Color(0xFF17EEFA);

  // ── Surface Hierarchy ──
  static const Color background = Color(0xFF0E0E0E);
  static const Color surface = Color(0xFF0E0E0E);
  static const Color surfaceContainerLowest = Color(0xFF000000);
  static const Color surfaceContainerLow = Color(0xFF131313);
  static const Color surfaceContainer = Color(0xFF1A1A1A);
  static const Color surfaceContainerHigh = Color(0xFF20201F);
  static const Color surfaceContainerHighest = Color(0xFF262626);
  static const Color surfaceBright = Color(0xFF2C2C2C);
  static const Color surfaceVariant = Color(0xFF262626);

  // ── On-Surface ──
  static const Color onSurface = Color(0xFFFFFFFF);
  static const Color onSurfaceVariant = Color(0xFFADAAAA);
  static const Color onBackground = Color(0xFFFFFFFF);

  // ── Error ──
  static const Color error = Color(0xFFFF7351);
  static const Color errorDim = Color(0xFFD53D18);
  static const Color errorContainer = Color(0xFFB92902);

  // ── Outline ──
  static const Color outline = Color(0xFF767575);
  static const Color outlineVariant = Color(0xFF484847);

  // ── Inverse ──
  static const Color inverseSurface = Color(0xFFFCF9F8);
  static const Color inversePrimary = Color(0xFF106F00);

  // ── Glow Effects ──
  static const Color primaryGlow = Color(0x268EFF71);  // 15% opacity
  static const Color secondaryGlow = Color(0x2600F1FD);
}
