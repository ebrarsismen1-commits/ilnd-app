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

  // ── Gündüz · lavanta zemin, beyaz yüzey ──────────────────────────────────────
  //
  // Ayrım KENARLIKLA değil ton farkıyla kurulur: zemin lavantaya çalan gri,
  // kartlar saf beyaz. Apple'ın gruplanmış liste dili — hairline yalnız grup
  // içi satır ayracında kalır.
  static const light = AppPalette(
    isDark: false,
    base: Color(0xFFF2F0F7),
    aura: [Color(0xFFF2F0F7), Color(0xFFEDEAF4), Color(0xFFF4F2F8)],
    surface: Color(0xFFFFFFFF),
    surfaceStrong: Color(0xFFEAE7F0),
    text: Color(0xFF161320),
    textMuted: Color(0xFF6B6478), // krem-lavanta zeminde ~4.7:1 (AA)
    border: Color(0xFFE4E0EC),
    accent: Color(0xFF6941B5), // lavanta — marka ve eylem rengi, ~6.4:1
    accentSoft: Color(0xFFEDE6FA),
    amber: Color(0xFF6E7F43), // matcha — pop; metin olarak okunabilir ton
    onAccent: Color(0xFFFFFFFF),
  );

  // ── Gece · mora çalan koyular ────────────────────────────────────────────────
  //
  // Nötr gri hâlâ YASAK (Sert Kural #7); gecenin rengi artık yeşile değil
  // MORA çalıyor. Koyu modun tonları açık modun ters çevrilmişi değil, ayrı
  // seçilmiş değerler — kontrastlar bağımsız ölçüldü.
  static const dark = AppPalette(
    isDark: true,
    base: Color(0xFF0F0D15),
    aura: [Color(0xFF110F18), Color(0xFF171422), Color(0xFF0F0D15)],
    surface: Color(0xFF1B1826),
    surfaceStrong: Color(0xFF231F31),
    text: Color(0xFFF3F1F7),
    textMuted: Color(0xFF918AA1), // koyu zeminde ~6.9:1
    border: Color(0x1FFFFFFF),
    accent: Color(0xFFB69CFF), // parlak lavanta, ~7.9:1
    accentSoft: Color(0xFF2A2440),
    amber: Color(0xFFA8BC7B), // matcha, ~8.7:1
    onAccent: Color(0xFF1A1226),
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
