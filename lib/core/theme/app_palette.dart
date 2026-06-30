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

  // ── Gündüz · pastel wellness × gen-z ─────────────────────────────────────────
  static const light = AppPalette(
    isDark: false,
    base: Color(0xFFF7F5FF), // barely-lavender white
    aura: [Color(0xFFF7F5FF), Color(0xFFF0ECFF), Color(0xFFF5F0FF)],
    surface: Color(0xFFFFFFFF),
    surfaceStrong: Color(0xFFEFECFF),
    text: Color(0xFF1E1B2E), // deep purple-black
    textMuted: Color(0xFF8B85A0), // dusty lilac-gray
    border: Color(0xFFE4DFFF), // lavender border
    accent: Color(0xFF8B5CF6), // violet-purple
    accentSoft: Color(0xFFEDE9FF),
    amber: Color(0xFFF472B6), // blush pink pop
    onAccent: Color(0xFFFFFFFF),
  );

  // ── Gece · deep purple luxe ───────────────────────────────────────────────────
  static const dark = AppPalette(
    isDark: true,
    base: Color(0xFF0F0D1A), // deep purple-black
    aura: [Color(0xFF120F1E), Color(0xFF1A1528), Color(0xFF0F0D1A)],
    surface: Color(0x18FFFFFF),
    surfaceStrong: Color(0xFF1E1A2E),
    text: Color(0xFFF0EEFF),
    textMuted: Color(0xFF9B94B8),
    border: Color(0x28FFFFFF),
    accent: Color(0xFFA78BFA), // lighter violet for dark mode
    accentSoft: Color(0xFF4C3B8A),
    amber: Color(0xFFF9A8D4), // soft pink
    onAccent: Color(0xFF0F0D1A),
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
