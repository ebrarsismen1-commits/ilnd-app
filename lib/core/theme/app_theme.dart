import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

export 'app_colors.dart';
export 'app_text_styles.dart';

/// Shared layout constants for the ILND design system.
class AppSpacing {
  AppSpacing._();

  /// Base spacing unit.
  static const double unit = 8;

  /// Horizontal screen padding.
  static const double screenPadding = 20;

  /// Card internal padding.
  static const double cardPadding = 16;

  /// Vertical gap between major sections.
  static const double sectionGap = 24;

  /// Standard card corner radius.
  static const double radius = 16;

  /// Small corner radius — inputs, pills, small cards.
  static const double radiusSmall = 8;
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.cream,
      colorScheme: const ColorScheme.light(
        primary: AppColors.sage,
        onPrimary: AppColors.white,
        secondary: AppColors.amber,
        onSecondary: AppColors.white,
        surface: AppColors.white,
        onSurface: AppColors.charcoal,
        surfaceContainerHighest: AppColors.creamDark,
        outline: AppColors.border,
        error: Color(0xFFB3554A),
      ),

      // ── Typography ──────────────────────────────────────────────────────
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).copyWith(
        // Display — Playfair italic (screen titles / hero text)
        displayLarge: AppTextStyles.display(fontSize: 56),
        displayMedium: AppTextStyles.display(fontSize: 40),
        displaySmall: AppTextStyles.display(fontSize: 28),

        // Heading — Playfair regular (card titles, article titles)
        headlineLarge: AppTextStyles.heading(fontSize: 26),
        headlineMedium: AppTextStyles.heading(fontSize: 22),
        headlineSmall: AppTextStyles.heading(fontSize: 18),
        titleLarge: AppTextStyles.heading(fontSize: 16),

        // Body — DM Sans 400
        bodyLarge: AppTextStyles.body(fontSize: 16),
        bodyMedium: AppTextStyles.body(fontSize: 14),
        bodySmall: AppTextStyles.body(
          fontSize: 13,
          color: AppColors.muted,
        ),

        // Label — DM Sans 500, uppercase, tracked
        labelLarge: AppTextStyles.label(fontSize: 13),
        labelMedium: AppTextStyles.label(fontSize: 11),
        labelSmall: AppTextStyles.label(fontSize: 10),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 0.5,
        space: 0.5,
      ),

      // ── Cards ───────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),

      // ── Buttons ─────────────────────────────────────────────────────────
      // Primary: sage fill, white text, DM Sans 500, height 52, radius 12.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sage,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.sage.withValues(alpha: 0.3),
          disabledForegroundColor: AppColors.white.withValues(alpha: 0.7),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Secondary: cream-dark fill, charcoal text.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.creamDark,
          foregroundColor: AppColors.charcoal,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Ghost: transparent, 0.5px sage border, sage text.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.sage,
          backgroundColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: AppColors.sage, width: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.sage,
          textStyle: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // ── Inputs ──────────────────────────────────────────────────────────
      // Cream-dark background, no border, radius 12, height 52.
      // Focus: 1px sage border.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.creamDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: AppTextStyles.display(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.muted,
        ),
        labelStyle: AppTextStyles.body(fontSize: 14, color: AppColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.sage, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFB3554A), width: 1),
        ),
      ),

      // ── App bar ─────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.display(fontSize: 20),
        iconTheme: const IconThemeData(color: AppColors.charcoal),
      ),

      // ── Bottom navigation ───────────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.cream,
        selectedItemColor: AppColors.sage,
        unselectedItemColor: AppColors.muted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),

      // ── Page transitions: fade + slight upward slide ──────────────────
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeUpTransitionsBuilder(),
          TargetPlatform.iOS: _FadeUpTransitionsBuilder(),
          TargetPlatform.macOS: _FadeUpTransitionsBuilder(),
          TargetPlatform.windows: _FadeUpTransitionsBuilder(),
          TargetPlatform.linux: _FadeUpTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Fade + slight upward slide page transition (~200ms), used app-wide.
class _FadeUpTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeUpTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
