import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ILND'nin çift kimliği.
///
/// Gündüz paleti 2026-09-11'de Figma "Ada" tasarımına (Page 2, 01 Marka ve
/// temeller) geçti: Kâğıt zemin, Mürekkep metin, Orman vurgu; yumuşak
/// yüzeyler Adaçayı / Su / Kil. Değerler tasarımın SVG dolgularından
/// okundu, gözle seçilmedi. Gece paleti aynı rolleri koyu karşılıklarıyla
/// taşır.
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
    required this.sea,
    required this.sky,
    required this.clay,
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

  /// Su: ada kartının deniz katmanı, ILND+ kartı, sohbet halkasının zemini.
  final Color sea;

  /// Ada kartının gökyüzü katmanı. İllüstrasyon gelene kadar ada kartı
  /// yalnız gökyüzü + deniz iki tonuyla çizilir (bkz. IslandFrame).
  final Color sky;

  /// Kil: sıcak vurgu zemini (hata/uyarı kartı, döngü takvimi).
  final Color clay;

  /// Yumuşak kart zeminleri (bkz. [InsightTints]).
  final InsightTints insight;

  // ── Gündüz · Ada (Figma Page 2) ──────────────────────────────────────────────
  static const light = AppPalette(
    isDark: false,
    base: Color(0xFFF6F5F1), // Kâğıt
    aura: [Color(0xFFF6F5F1), Color(0xFFF6F5F1), Color(0xFFF6F5F1)],
    surface: Color(0xFFFCFCF8), // kart ve giriş alanı dolgusu
    surfaceStrong: Color(0xFFE9EDDF), // Adaçayı: yumuşak kart, ikon karosu
    text: Color(0xFF22382E), // Mürekkep
    textMuted: Color(0xFF59675E), // Adaçayı üstünde de 5.0:1
    border: Color(0xFFDDDFD6),
    // Yeşil ve turuncu açık modda birer ton koyulaştı: eski değerlerde
    // (1F9D57 / E2611C) beyaz metinli birincil buton 3.49:1 idi, AA sınırı
    // 4.5. Ton aynı, parlaklık düştü. Koyu palet zaten geçiyordu, dokunulmadı.
    accent: Color(0xFF13763E), // Orman
    accentSoft: Color(0xFFE1EEDF), // aktif sekme hapı, halka zemini
    amber: Color(0xFFA84711), // warm orange pop, AA-safe
    danger: Color(0xFFA54A40),
    // Kenarlık #DDDFD6'ya koyulaşınca eski su mavisi (#2E86B8) kendi rayına
    // karşı 2.99:1'e düştü; bir tık koyulaştı.
    water: Color(0xFF2B7DAB),
    onAccent: Color(0xFFFFFFFF),
    sea: Color(0xFFDCECE7), // Su
    sky: Color(0xFFE6EEDE),
    clay: Color(0xFFECD1C5), // Kil
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
    sea: Color(0xFF16211E),
    sky: Color(0xFF1A2119),
    clay: Color(0xFF2A211D),
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
