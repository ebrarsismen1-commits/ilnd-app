import 'package:flutter/material.dart';

/// ILND brand color system — light-mode-only constants, kept `const` so
/// they remain usable as default-parameter/const-widget values across the
/// codebase (app_text_styles.dart, app_theme.dart, login/register screens).
///
/// IMPORTANT — single source of truth: `cream`/`sage`/`amber`/`charcoal`/
/// `muted`/`white`/`border` MUST always equal [AppPalette.light]'s
/// `base`/`accent`/`amber`/`text`/`textMuted`/`surface`/`border` one-for-one
/// (`sageLight`/`amberLight` have no AppPalette equivalent — they're
/// legacy-only mint/pink tints, not used by the dark-aware palette). These
/// can't be real Dart references to AppPalette.light's fields because that
/// would make them non-const, breaking every const default-param/const-widget
/// call site that currently depends on AppColors being compile-time constant.
/// If you change a shared light-mode color, update it in BOTH files.
///
/// New code should prefer `ref.watch(paletteProvider)` over [AppColors] —
/// it gets dark mode for free. Only reach for [AppColors] when no
/// [WidgetRef]/[Ref] is available (e.g. inside a `const` widget tree).
class AppColors {
  AppColors._();

  // ── Core palette — mirrors AppPalette.light, see class doc above ───────────

  static const cream = Color(0xFFF6F5F1);
  static const creamDark = Color(0xFFE9EDDF);
  static const sage = Color(0xFF13763E);
  static const sageLight = Color(0xFF7FCE9E);
  static const amber = Color(0xFFA84711);
  static const amberLight = Color(0xFFF3B489);
  static const charcoal = Color(0xFF22382E);
  static const muted = Color(0xFF59675E);
  static const white = Color(0xFFFCFCF8);
  static const border = Color(0xFFDDDFD6);

  // ── Legacy aliases ────────────────────────────────────────────────────────

  static const background = cream;
  static const primary = sage;
  static const secondary = sageLight;
  static const accent = amber;
  static const onPrimary = white;
  static const onBackground = charcoal;
  static const surface = white;
}
