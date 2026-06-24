import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// ILND typography system.
///
/// - Display  → Playfair Display *italic* — screen titles, hero text
///   ("ilnd.", "takip.", "keşfet.")
/// - Heading  → Playfair Display regular — card titles, food names,
///   article titles
/// - Body     → DM Sans 400 — descriptions, subtitles, body text
/// - Label    → DM Sans 500, uppercase, letter-spacing 0.08em — tags,
///   categories, stat labels
/// - Mono     → IBM Plex Mono — numbers, macros, stats (calories, protein)
class AppTextStyles {
  AppTextStyles._();

  // ── Display — Playfair Display italic ───────────────────────────────────

  static TextStyle display({
    double fontSize = 32,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.charcoal,
    double height = 1.05,
  }) {
    // Noto Serif, roman (italik değil), sıkı negatif aralık — ilnd.app'teki
    // büyük editoryal başlık dili.
    return GoogleFonts.notoSerif(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: -fontSize * 0.02,
    );
  }

  /// Large hero display, e.g. the "ilnd." splash wordmark.
  static TextStyle displayHero({Color color = AppColors.charcoal}) =>
      display(fontSize: 56, fontWeight: FontWeight.w600, color: color);

  // ── Heading — Noto Serif ─────────────────────────────────────────────────

  static TextStyle heading({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.charcoal,
    double height = 1.2,
  }) {
    return GoogleFonts.notoSerif(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: -fontSize * 0.01,
    );
  }

  // ── Body — DM Sans 400 ───────────────────────────────────────────────────

  static TextStyle body({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.charcoal,
    double height = 1.5,
  }) {
    return GoogleFonts.dmSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  // ── Label — DM Sans 500, uppercase, tracked ─────────────────────────────

  static TextStyle label({
    double fontSize = 11,
    Color color = AppColors.muted,
    double letterSpacingEm = 0.08,
  }) {
    return GoogleFonts.dmSans(
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      letterSpacing: fontSize * letterSpacingEm,
      color: color,
    );
  }

  /// Section labels — all caps, DM Sans 500, letter-spacing 0.12em, muted,
  /// font-size 11px.
  static TextStyle sectionLabel({Color color = AppColors.muted}) {
    return label(fontSize: 11, color: color, letterSpacingEm: 0.12);
  }

  // ── Mono — IBM Plex Mono ─────────────────────────────────────────────────

  static TextStyle mono({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w500,
    Color color = AppColors.charcoal,
    double height = 1.0,
  }) {
    return GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }
}
