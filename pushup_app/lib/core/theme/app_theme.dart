import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Complete Material 3 theme for the KINETIC AI app.
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        tertiary: AppColors.tertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        error: AppColors.error,
        errorContainer: AppColors.errorContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        inverseSurface: AppColors.inverseSurface,
        inversePrimary: AppColors.inversePrimary,
        surfaceContainerHighest: AppColors.surfaceContainerHighest,
      ),
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.lexend(
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: -1.5,
        ),
        headlineMedium: GoogleFonts.lexend(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineSmall: GoogleFonts.lexend(
          fontWeight: FontWeight.w700,
        ),
        titleLarge: GoogleFonts.lexend(fontWeight: FontWeight.w700),
        titleMedium: GoogleFonts.lexend(fontWeight: FontWeight.w700),
        titleSmall: GoogleFonts.lexend(fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(),
        bodyMedium: GoogleFonts.inter(),
        bodySmall: GoogleFonts.inter(),
        labelLarge: GoogleFonts.spaceGrotesk(
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
        labelMedium: GoogleFonts.spaceGrotesk(
          fontWeight: FontWeight.w500,
          letterSpacing: 1.5,
        ),
        labelSmall: GoogleFonts.spaceGrotesk(
          fontWeight: FontWeight.w500,
          letterSpacing: 2.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background.withValues(alpha: 0.8),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.lexend(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          color: AppColors.primary,
          letterSpacing: -1,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
        border: InputBorder.none,
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.transparent, width: 2),
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.secondary, width: 2),
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        hintStyle: GoogleFonts.inter(
          color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 48,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
          textStyle: GoogleFonts.lexend(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
          elevation: 0,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.background.withValues(alpha: 0.9),
        indicatorColor: AppColors.primary.withValues(alpha: 0.1),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: AppColors.primary,
            );
          }
          return GoogleFonts.spaceGrotesk(
            fontSize: 10,
            letterSpacing: 2,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
          );
        }),
      ),
    );
  }
}
