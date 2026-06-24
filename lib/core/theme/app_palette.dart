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

  // ── Gündüz · açık, havadar, gri-tonlu ────────────────────────────────────────
  static const light = AppPalette(
    isDark: false,
    base: Color(0xFFF5F4F1), // havadar, neredeyse beyaz
    aura: [Color(0xFFF6F5F2), Color(0xFFF0EFEB), Color(0xFFEDF0EA)], // fısıltı tonları
    surface: Color(0xF2FFFFFF), // beyaz kart
    surfaceStrong: Color(0xFFEDEBE6),
    text: Color(0xFF111827), // neredeyse siyah arduvaz (ilnd.app)
    textMuted: Color(0xFF6B7280), // gri-500 (ilnd.app)
    border: Color(0x1A111827),
    accent: Color(0xFF1F9D57), // yeşil (ilnd.app green-600 ailesi)
    accentSoft: Color(0xFF8FBE9F),
    amber: Color(0xFFE2611C), // turuncu pop (ilnd.app)
    onAccent: Color(0xFFFFFFFF),
  );

  // ── Gece · soğuk kömür luxe ──────────────────────────────────────────────────
  static const dark = AppPalette(
    isDark: true,
    base: Color(0xFF14161B),
    aura: [Color(0xFF181B21), Color(0xFF1E2129), Color(0xFF15171C)],
    surface: Color(0x14FFFFFF),
    surfaceStrong: Color(0xFF20242B),
    text: Color(0xFFF3F4F6),
    textMuted: Color(0xFF9AA0AB),
    border: Color(0x24FFFFFF),
    accent: Color(0xFF34C77B), // dark modda daha parlak yeşil
    accentSoft: Color(0xFF2E7D52),
    amber: Color(0xFFF0853F),
    onAccent: Color(0xFF0E1014),
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
