import 'package:flutter/material.dart';

/// ILND brand color system.
///
/// Pastel wellness × Gen-Z: lavender base, blush + mint accents,
/// clean whites, soft purple-gray text.
class AppColors {
  AppColors._();

  // ── Core palette ──────────────────────────────────────────────────────────

  /// Primary background — barely-lavender white.
  static const cream = Color(0xFFF7F5FF);

  /// Card backgrounds, input fields — soft lavender tint.
  static const creamDark = Color(0xFFEFECFF);

  /// Primary action — medium violet (gen-z lavender).
  static const sage = Color(0xFF8B5CF6);

  /// Secondary — mint green pastel.
  static const sageLight = Color(0xFF6EE7B7);

  /// Accent — blush rose pink.
  static const amber = Color(0xFFF472B6);

  /// Accent tint.
  static const amberLight = Color(0xFFFBBFE0);

  /// Primary text — deep purple-black.
  static const charcoal = Color(0xFF1E1B2E);

  /// Secondary text — dusty lilac-gray.
  static const muted = Color(0xFF8B85A0);

  /// Card / surface color.
  static const white = Color(0xFFFFFFFF);

  /// Hairline border — lavender tint.
  static const border = Color(0xFFE4DFFF);

  // ── Legacy aliases ────────────────────────────────────────────────────────

  static const background = cream;
  static const primary = sage;
  static const secondary = sageLight;
  static const accent = amber;
  static const onPrimary = white;
  static const onBackground = charcoal;
  static const surface = white;
}
