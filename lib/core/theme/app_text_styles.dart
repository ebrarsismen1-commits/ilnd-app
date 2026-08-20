import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// ILND tipografi sistemi.
///
/// **Noto Serif** (başlık/editoryal an) + **DM Sans** (gövde/etiket) +
/// **IBM Plex Mono** (sayı). Tasarım handoff'unun (2026-08-18,
/// "editoryal ekran yenilemesi") birebir uygulanması — owner kararı.
///
/// Tarihçe, çünkü bu ikinci kez değişti ve gerekçeler birbirini iptal ediyor:
/// 2026-08-14'te bu üçlü Sora + Inter'e çevrilmişti (gerekçe: eski eşleşme
/// başka bir ürünün arayüzünü hatırlatıyordu, Plex'in noktalı sıfırı
/// sevilmiyordu). 2026-08-18'de owner handoff'u birebir istedi ve üçlü geri
/// geldi. Yeniden değiştirmeden önce ikisini de oku — ikisi de savunulabilir,
/// karar estetik ve owner'ın.
///
/// - display / heading → Noto Serif — ekran adı, kart başlığı, editoryal an
/// - body / label      → DM Sans — gövde, alt satır, etiket
/// - mono              → IBM Plex Mono — kalori, streak, makro, sayaç
class AppTextStyles {
  AppTextStyles._();

  // ── Ölçek — VARSAYILAN roller ────────────────────────────────────────────
  //
  // Bu değerler artık bir kilit değil, **varsayılan**. 2026-08-14'te ölçek 10
  // role indirilip test'le kilitlenmişti; 2026-08-18 handoff'u ekran başına
  // kendi puntolarını getirdiği için kilit kaldırıldı (owner kararı).
  //
  // Kilidin yerine iki daha zayıf ama hâlâ işe yarayan koruma kondu
  // (test/core/typography_test.dart): (1) lib/ içinde bu üç aile dışında font
  // kullanılamaz, (2) fontSize değerleri handoff'un belgelenmiş kümesinden
  // gelmeli — rastgele bir 37 hâlâ CI'da kırılır.
  //
  // Adlandırılmış rol varsa onu kullan; handoff bir ekran için özel punto
  // veriyorsa çağrı yerinde açıkça yaz.
  static const double sizeHero = 44; // splash wordmark
  static const double sizeTitle = 30; // ekran adı ("Bugün")
  static const double sizeHeadline = 24; // bölüm/kart başlığı
  static const double sizeTitle3 = 19; // alt başlık, makale adı
  static const double sizeBody = 15; // gövde — okunabilirlik tabanı
  static const double sizeCallout = 13; // ikincil gövde, kart alt satırı
  static const double sizeFootnote = 11.5; // yardımcı metin
  static const double sizeCaption = 10; // etiket, rozet

  /// Büyük sayı anı (kalori, streak) — ekranın tek kahramanı.
  static const double sizeMetric = 28;
  static const double sizeMetricLarge = 40;

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

  /// Sayılar — IBM Plex Mono. Kalori, streak, makro, etkinlik günü, sayaç.
  ///
  /// Monospace burada süs değil hizalama aracı: alt alta gelen makro değerleri
  /// ve 999→1000'e geçen sayaçlar satırı zıplatmaz. (Aynı hizayı Inter'de
  /// `tabularFigures` veriyordu; handoff monospace istediği için geri döndük.)
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

  // ── Adlandırılmış roller — çağrı yerleri BUNLARI kullanır ─────────────────

  /// Ekran adı — `keşfet.` `takip` `adan.` gibi. Handoff'ta serif:
  /// Noto Serif 600, sıkı negatif aralık. Ekran başına punto farkı için
  /// (30 / 28 / 26) `fontSize` geçilebilir.
  static TextStyle screenTitle({required Color color, double? fontSize}) =>
      display(
        fontSize: fontSize ?? sizeTitle,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.1,
      );

  /// Editoryal an — selamlama, makale başlığı. Serifin kaldığı tek yer.
  static TextStyle editorial({
    required Color color,
    double fontSize = sizeHeadline,
  }) => display(fontSize: fontSize, color: color, height: 1.2);

  /// Kart/bölüm başlığı.
  static TextStyle cardTitle({required Color color}) => body(
    fontSize: sizeBody,
    color: color,
  ).copyWith(fontWeight: FontWeight.w600);

  /// Gövde metni. 15px taban — mobilde okunabilirlik alt sınırı.
  static TextStyle bodyText({required Color color}) =>
      body(fontSize: sizeBody, color: color);

  /// İkincil gövde, kart alt satırı.
  static TextStyle callout({required Color color}) =>
      body(fontSize: sizeCallout, color: color);

  /// Yardımcı/açıklama metni.
  static TextStyle footnote({required Color color}) =>
      body(fontSize: sizeFootnote, color: color);

  /// Büyük sayı anı — kalori, streak. Ekranın kahramanı.
  static TextStyle metric({required Color color, bool large = false}) => mono(
    fontSize: large ? sizeMetricLarge : sizeMetric,
    fontWeight: FontWeight.w700,
    color: color,
  ).copyWith(letterSpacing: -1.2);
}
