import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Reusable text styles matching the KINETIC design system.
/// Headline = Lexend, Body = Inter, Label = Space Grotesk
class AppTextStyles {
  AppTextStyles._();

  // ── Headlines (Lexend) ──
  static TextStyle headlineXL = GoogleFonts.lexend(
    fontSize: 48,
    fontWeight: FontWeight.w900,
    fontStyle: FontStyle.italic,
    letterSpacing: -2,
    color: AppColors.onSurface,
  );

  static TextStyle headlineLarge = GoogleFonts.lexend(
    fontSize: 36,
    fontWeight: FontWeight.w900,
    fontStyle: FontStyle.italic,
    letterSpacing: -1.5,
    color: AppColors.onSurface,
  );

  static TextStyle headlineMedium = GoogleFonts.lexend(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: AppColors.onSurface,
  );

  static TextStyle headlineSmall = GoogleFonts.lexend(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.onSurface,
  );

  static TextStyle titleLarge = GoogleFonts.lexend(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.onSurface,
  );

  static TextStyle titleMedium = GoogleFonts.lexend(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.onSurface,
  );

  // ── Body (Inter) ──
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );

  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurfaceVariant,
  );

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurfaceVariant,
  );

  // ── Labels (Space Grotesk) ──
  static TextStyle labelLarge = GoogleFonts.spaceGrotesk(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
    color: AppColors.onSurfaceVariant,
  );

  static TextStyle labelMedium = GoogleFonts.spaceGrotesk(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    color: AppColors.onSurfaceVariant,
  );

  static TextStyle labelSmall = GoogleFonts.spaceGrotesk(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 2.5,
    color: AppColors.onSurfaceVariant,
  );

  // ── Special Styles ──
  static TextStyle brandTitle = GoogleFonts.lexend(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    fontStyle: FontStyle.italic,
    letterSpacing: -1,
    color: AppColors.primary,
  );

  static TextStyle statValue = GoogleFonts.lexend(
    fontSize: 48,
    fontWeight: FontWeight.w900,
    color: AppColors.onSurface,
  );

  static TextStyle buttonText = GoogleFonts.lexend(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 3,
    color: AppColors.onPrimary,
  );
}
