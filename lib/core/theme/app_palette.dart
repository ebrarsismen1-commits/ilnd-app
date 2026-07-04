import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ILND'nin çift kimliği — ilnd.app'ten birebir türetilmiş:
/// gündüz açık/havadar/gri-tonlu + nokta atışı yeşil-turuncu vurgu,
/// gece soğuk kömür luxe. Renk fotoğraflardan gelir, arayüzden değil.
class AppPalette {
  const AppPalette({
    required this.isDark,
    required this.base,
    required this.aura,
    required this.surface,
    required this.surfaceStrong,
    required this.text,
    required this.textMuted,
    required this.border,
    required this.accent,
    required this.accentSoft,
    required this.amber,
    required this.onAccent,
  });

  final bool isDark;

  /// Aura'nın altındaki düz taban renk.
  final Color base;

  /// Akan arka plan degradesi — neredeyse görünmez, havadar.
  final List<Color> aura;

  final Color surface;
  final Color surfaceStrong;
  final Color text;
  final Color textMuted;
  final Color border;

  /// Birincil vurgu (yeşil — ilnd.app).
  final Color accent;
  final Color accentSoft;

  /// İkincil vurgu / pop (sıcak turuncu — ilnd.app).
  final Color amber;

  final Color onAccent;

  // ── Gündüz · açık/havadar/gri-tonlu wellness ─────────────────────────────────
  static const light = AppPalette(
    isDark: false,
    base: Color(0xFFF5F4F1), // barely-there off-white
    aura: [Color(0xFFF5F4F1), Color(0xFFEEEDE6), Color(0xFFF2F1EA)],
    surface: Color(0xFFFFFFFF),
    surfaceStrong: Color(0xFFEBE8E1),
    text: Color(0xFF111827), // slate
    textMuted: Color(0xFF6B7280),
    border: Color(0xFFE3E0D8),
    accent: Color(0xFF1F9D57), // ilnd.app green
    accentSoft: Color(0xFFDCF3E4),
    amber: Color(0xFFE2611C), // warm orange pop
    onAccent: Color(0xFFFFFFFF),
  );

  // ── Gece · soğuk kömür luxe ───────────────────────────────────────────────────
  static const dark = AppPalette(
    isDark: true,
    base: Color(0xFF10120F), // cool near-black coal
    aura: [Color(0xFF12140F), Color(0xFF181C16), Color(0xFF10120F)],
    surface: Color(0x18FFFFFF),
    surfaceStrong: Color(0xFF1C211C),
    text: Color(0xFFF1F3EF),
    textMuted: Color(0xFF9AA39A),
    border: Color(0x28FFFFFF),
    accent: Color(0xFF34C77A), // brighter green for dark-mode contrast
    accentSoft: Color(0xFF1E3A2A),
    amber: Color(0xFFF2794A), // lighter orange for dark-mode contrast
    onAccent: Color(0xFF0B140D),
  );
}

/// Aktif tema parlaklığı — gece/gündüz geçişini yönetir.
final themeModeProvider = StateProvider<Brightness>((ref) => Brightness.light);

/// O anki palet.
final paletteProvider = Provider<AppPalette>((ref) {
  return ref.watch(themeModeProvider) == Brightness.dark
      ? AppPalette.dark
      : AppPalette.light;
});
