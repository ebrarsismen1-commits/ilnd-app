import 'package:flutter/material.dart';

/// ILND brand color system.
///
/// Editorial / prestige lifestyle palette — Kinfolk / Goop / Byredo
/// inspired. Warm cream backgrounds, sage greens for primary actions,
/// amber for accents and warmth.
class AppColors {
  AppColors._();

  // ── Core palette ──────────────────────────────────────────────────────────

  /// Primary background — warm cream.
  static const cream = Color(0xFFF5F0E8);

  /// Card backgrounds, input fields — slightly deeper cream.
  static const creamDark = Color(0xFFEDE8DF);

  /// Primary action color, active states, progress indicators.
  static const sage = Color(0xFF6B8F5E);

  /// Secondary sage — habit checkboxes, soft active states.
  static const sageLight = Color(0xFFA8C49A);

  /// Accent color — warnings, fat macro, secondary highlights.
  static const amber = Color(0xFFC4956A);

  /// Amber tint — backgrounds for amber-accented elements.
  static const amberLight = Color(0xFFE8C9A0);

  /// Primary text color.
  static const charcoal = Color(0xFF2C2C2A);

  /// Secondary text, placeholders.
  static const muted = Color(0xFF8C8880);

  /// Card / surface color.
  static const white = Color(0xFFFFFFFF);

  /// Hairline border color for cards and dividers.
  static const border = Color(0xFFE8E4DC);

  // ── Legacy aliases ────────────────────────────────────────────────────────
  // Kept so existing screens referencing the old token names keep compiling.

  static const background = cream;
  static const primary = sage;
  static const secondary = sageLight;
  static const accent = amber;
  static const onPrimary = white;
  static const onBackground = charcoal;
  static const surface = white;
}
