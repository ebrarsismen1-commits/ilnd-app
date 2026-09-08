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
    required this.danger,
    required this.water,
    required this.onAccent,
    required this.insight,
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

  /// Hata / yıkıcı eylem. Dört ekranda ayrı ayrı sabit yazılmıştı, tek
  /// kaynağa alındı (kural #6).
  final Color danger;

  /// Su ilerlemesi. Açık modda kendi rayına (border) karşı en az 3:1
  /// olmalı — anlam taşıyan grafik, dekorasyon değil.
  final Color water;

  final Color onAccent;

  /// Yumuşak kart zeminleri (bkz. [InsightTints]).
  final InsightTints insight;

  // ── Gündüz · açık/havadar/gri-tonlu wellness ─────────────────────────────────
  static const light = AppPalette(
    isDark: false,
    base: Color(0xFFF5F4F1), // barely-there off-white
    aura: [Color(0xFFF5F4F1), Color(0xFFEEEDE6), Color(0xFFF2F1EA)],
    surface: Color(0xFFFFFFFF),
    surfaceStrong: Color(0xFFEBE8E1),
    text: Color(0xFF111827), // slate
    textMuted: Color(0xFF5F6875), // WCAG AA: 6B7280 zeminde 4.40 kalıyordu
    border: Color(0xFFE3E0D8),
    // Yeşil ve turuncu açık modda birer ton koyulaştı: eski değerlerde
    // (1F9D57 / E2611C) beyaz metinli birincil buton 3.49:1 idi, AA sınırı
    // 4.5. Ton aynı, parlaklık düştü. Koyu palet zaten geçiyordu, dokunulmadı.
    accent: Color(0xFF13763E), // ilnd.app green, AA-safe
    accentSoft: Color(0xFFDCF3E4),
    amber: Color(0xFFA84711), // warm orange pop, AA-safe
    danger: Color(0xFFA54A40),
    water: Color(0xFF2E86B8),
    onAccent: Color(0xFFFFFFFF),
    insight: InsightTints(
      blush: Color(0xFFF7EBE9),
      cream: Color(0xFFF5F0E1),
      peach: Color(0xFFFAEDE0),
      lavender: Color(0xFFEEECF6),
      sage: Color(0xFFE8EFE7),
      neutral: Color(0xFFF1EDE6),
    ),
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
    danger: Color(0xFFDA8578),
    water: Color(0xFF93D5FF),
    onAccent: Color(0xFF0B140D),
    insight: InsightTints(
      blush: Color(0xFF221D1C),
      cream: Color(0xFF211F17),
      peach: Color(0xFF241E16),
      lavender: Color(0xFF1C1C23),
      sage: Color(0xFF182018),
      neutral: Color(0xFF1F1E19),
    ),
  );
}

/// İçgörü kartlarının yumuşak zeminleri (Keşfet · "Bugün senin için" rafı).
///
/// Kart zemini paletin dışında sabit hex olarak yazılsaydı kural #6'ya
/// takılırdı: renk yalnız paletten gelir. Altı ton tek bir sette duruyor ki
/// gece karşılığı unutulmasın ve kontrast testi hepsini birden ölçebilsin.
///
/// Gündüz tonları neredeyse beyaz, "kutu" değil "kağıt" hissi verir; gece
/// karşılıkları taban rengin (#10120F) üstüne oturan koyu, hue'su korunmuş
/// yüzeylerdir (nötr gri YASAK, DESIGN_SYSTEM §1).
class InsightTints {
  const InsightTints({
    required this.blush,
    required this.cream,
    required this.peach,
    required this.lavender,
    required this.sage,
    required this.neutral,
  });

  final Color blush;
  final Color cream;
  final Color peach;
  final Color lavender;
  final Color sage;
  final Color neutral;

  /// Kontrast testi ve raf sırası için sabit sıra.
  List<Color> get all => [blush, cream, peach, lavender, sage, neutral];
}

/// Aktif tema parlaklığı — gece/gündüz geçişini yönetir.
final themeModeProvider = StateProvider<Brightness>((ref) => Brightness.light);

/// O anki palet.
final paletteProvider = Provider<AppPalette>((ref) {
  return ref.watch(themeModeProvider) == Brightness.dark
      ? AppPalette.dark
      : AppPalette.light;
});
