import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// ILND tipografi sistemi.
///
/// **Sora** (başlık/sayı) + **Inter** (gövde/etiket). İkisi de tek eksende
/// çalışır: geometrik, sıcak olmayan, modern.
///
/// Neden değişti (2026-08-14): önceki eşleşme Noto Serif + DM Sans idi ve
/// sıcak zeminle birlikte **Claude'un arayüzüne fazla benziyordu** — duygusal
/// bir üründe "bunu bir yerden hatırlıyorum" hissi ayrışmayı öldürür.
/// IBM Plex Mono da kaldırıldı: noktalı sıfırı sayıları çirkinleştiriyordu.
///
/// - display / heading → Sora — ekran adı, kart başlığı, editoryal an
/// - body / label      → Inter — gövde, alt satır, etiket
/// - mono              → Sora + tabular figures — kalori, streak, makro
class AppTextStyles {
  AppTextStyles._();

  // ── Ölçek — TEK KAYNAK ────────────────────────────────────────────────────
  //
  // Denetim (2026-08-11): kod tabanında 33 ayrı `fontSize` vardı, çünkü her
  // çağrı yeri kendi sayısını uyduruyordu. Ekranlar arası "farklı yazı tipi
  // varmış gibi" hissinin sebebi buydu — font aynıydı, ÖLÇEK dağınıktı.
  //
  // Bundan sonra kural: **çağrı yerinde çıplak sayı yok.** Aşağıdaki adlandı-
  // rılmış roller kullanılır. Yeni bir boyut gerçekten gerekiyorsa önce buraya
  // eklenir (test bunu kilitler: test/core/type_scale_test.dart).
  //
  // Apple'ın tip rolleri gibi az sayıda ve amaç-adlı; ölçek 1.25 oranında.
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
    return GoogleFonts.sora(
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
    return GoogleFonts.sora(
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
    return GoogleFonts.inter(
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
    return GoogleFonts.inter(
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

  /// Sayılar. Adı tarihsel olarak `mono` ama artık monospace DEĞİL.
  ///
  /// Font seçimi burada tamamen **sıfırın şekline** göre yapıldı:
  /// IBM Plex Mono'nun sıfırı noktalıydı, Sora'nınki de öyle görünüyordu.
  /// Inter'in varsayılan sıfırı düz bir ovaldir — noktalı/çizgili sıfır o
  /// fontta yalnız `zero`/`ss02` özelliği elle açılırsa gelir, açmıyoruz.
  ///
  /// **tabular figures** açık: rakamlar eşit genişlikte, alt alta gelen
  /// sayılar hizalanır ve sayaç 999→1000 olurken satır zıplamaz. Hizayı veren
  /// şey monospace olmak değil, tnum özelliğidir.
  static TextStyle mono({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w500,
    Color color = AppColors.charcoal,
    double height = 1.0,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  // ── Adlandırılmış roller — çağrı yerleri BUNLARI kullanır ─────────────────

  /// Ekran adı. Apple'ın "large title" karşılığı: sans, kalın, sıkı aralık.
  /// Serif DEĞİL — serif artık yalnız editoryal anlarda (selamlama, makale).
  static TextStyle screenTitle({required Color color}) => GoogleFonts.inter(
    fontSize: sizeTitle,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1.15,
    letterSpacing: -0.9,
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
