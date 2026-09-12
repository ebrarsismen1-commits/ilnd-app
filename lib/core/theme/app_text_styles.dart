import 'package:flutter/material.dart';

import 'app_colors.dart';

/// ILND tipografi sistemi.
///
/// **Lora** (başlık) + **DM Sans** (gövde, etiket) + **DM Mono** (sayı).
/// Üçü de pakete gömülüdür (pubspec.yaml `fonts:`), hiçbiri çalışma anında
/// indirilmez.
///
/// Tarihçe, çünkü bu dördüncü kez değişiyor ve gerekçeler birbirini iptal
/// ediyor: 2026-08-14'te Noto Serif + DM Sans + IBM Plex Mono üçlüsü
/// Sora + Inter'e çevrildi (eski eşleşme başka bir ürünün arayüzünü
/// hatırlatıyordu, Plex'in noktalı sıfırı sevilmiyordu). 2026-08-18'de owner
/// handoff'u birebir istedi, üçlü geri geldi. 2026-08-31'de dağıtım yalnız
/// iOS olunca gövde ve sayılar bir süre sistem fontuna (SF Pro) alındı, sonra
/// aynı gün owner eski tipografiye dönmeyi seçti; sayılar bu kez IBM Plex
/// Mono yerine DM Mono'ya bağlandı (DM Sans'ın kendi monospace kardeşi,
/// eşleşme daha doğal). Yeniden değiştirmeden önce hepsini oku: her biri
/// savunulabilir, karar estetik ve owner'ın.
///
/// - display / heading → Lora, ILND'nin editoryal imzası
/// - body / label      → DM Sans
/// - mono              → DM Mono, kalori ve sayaç
///
/// 2026-09-12: Ada tasarımının başlık fontu **Lora** pakete gömüldü ve
/// Noto Serif kaldırıldı (owner onayı). Google Fonts Lora'yı yalnız
/// değişken kesim olarak yayınlıyor; 400/600 ve italik 400 statik
/// kesimleri fonttools ile üretildi. display/heading varsayılan ağırlığı
/// da 600'den 400'e indi: tasarımın başlıkları kalın değil, hafif.
///
/// **DM Mono 500'de biter** (600/700 kesimi üretilmemiş). Sayı stilleri bu
/// yüzden 500'e sabitlendi; daha kalın istemek Flutter'ı en yakın kesime
/// düşürür, yani kod 700 der ekran 500 çizerdi. Sayıların hizalaması
/// monospace olmasından gelir, `tabularFigures` gerekmiyor.
///
class AppTextStyles {
  AppTextStyles._();

  /// Başlıkların ailesi. Pakete gömülü, indirilmiyor.
  static const String serifFont = 'Lora';

  /// Gövde ve etiketlerin ailesi. Pakete gömülü.
  static const String sansFont = 'DMSans';

  /// Sayıların ailesi: DM Sans'ın monospace kardeşi. Pakete gömülü.
  /// En kalın kesimi 500'dür (bkz. sınıf açıklaması).
  static const String monoFont = 'DMMono';

  /// Sayı stillerinin üst ağırlığı. DM Mono'da 500'ün üstü yok; sabit olarak
  /// durması, çağrı yerlerinin var olmayan bir kalınlık istemesini önlüyor.
  static const FontWeight monoMaxWeight = FontWeight.w500;

  // ── Ölçek — VARSAYILAN roller ────────────────────────────────────────────
  //
  // Bu değerler artık bir kilit değil, **varsayılan**. 2026-08-14'te ölçek 10
  // role indirilip test'le kilitlenmişti; 2026-08-18 handoff'u ekran başına
  // kendi puntolarını getirdiği için kilit kaldırıldı (owner kararı).
  //
  // Kilidin yerine iki daha zayıf ama hâlâ işe yarayan koruma kondu
  // (test/core/typography_test.dart): (1) lib/ içinde indirilen font
  // kullanılamaz, (2) fontSize değerleri handoff'un
  // belgelenmiş kümesinden gelmeli, rastgele bir 37 hâlâ CI'da kırılır.
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

  // ── Display — Lora (ILND'nin imzası) ────────────────────────────────────

  static TextStyle display({
    double fontSize = 32,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.charcoal,
    double height = 1.05,
  }) {
    // Lora, roman (italik değil), sıkı negatif aralık — ilnd.app'teki
    // büyük editoryal başlık dili.
    return TextStyle(
      fontFamily: serifFont,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: -fontSize * 0.02,
    );
  }

  /// Large hero display, e.g. the "ilnd." splash wordmark.
  static TextStyle displayHero({Color color = AppColors.charcoal}) =>
      display(fontSize: 56, color: color);

  // ── Heading — Lora ───────────────────────────────────────────────────────

  static TextStyle heading({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.charcoal,
    double height = 1.2,
  }) {
    return TextStyle(
      fontFamily: serifFont,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: -fontSize * 0.01,
    );
  }

  // ── Body — DM Sans ──────────────────────────────────────────────────────

  /// Gövde metni sistemin kendi fontuyla çizilir.
  ///
  /// `fontFamily` BİLEREK boş: Flutter, aile verilmediğinde platformun
  /// varsayılanını kullanır ve iOS'ta bu San Francisco'dur. Apple'ın
  /// `.SF Pro Text` gibi nokta önekli adları özeldir, belgelenmemiştir ve
  /// sürümle değişebilir; aileyi hiç vermemek aynı sonucu güvenle verir.
  ///
  /// Karar (31 Ağustos 2026): ILND'nin tipografik karakterini yalnız
  /// başlıklar ve logo taşır. Gövde yerli iOS metni gibi okunur, bu da
  /// Dynamic Type ve sistem hinting'iyle doğal uyum demektir.
  static TextStyle body({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.charcoal,
    double height = 1.5,
  }) {
    return TextStyle(
      fontFamily: sansFont,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  // ── Label — DM Sans 500, büyük harf, aralıklı ───────────────────────────

  static TextStyle label({
    double fontSize = 11,
    Color color = AppColors.muted,
    double letterSpacingEm = 0.08,
  }) {
    return TextStyle(
      fontFamily: sansFont,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      letterSpacing: fontSize * letterSpacingEm,
      color: color,
    );
  }

  /// Bölüm etiketleri — ALL CAPS, 500, 0.12em aralık, muted, 11px.
  static TextStyle sectionLabel({Color color = AppColors.muted}) {
    return label(fontSize: 11, color: color, letterSpacingEm: 0.12);
  }

  // ── Sayılar — DM Mono ───────────────────────────────────────────────────

  /// Sayılar: kalori, streak, makro, etkinlik günü, sayaç.
  ///
  /// Buradaki asıl gereksinim hizalamaydı, monospace ailenin kendisi değil:
  /// alt alta gelen makro değerleri ve 999'dan 1000'e geçen sayaçlar satırı
  /// zıplatmamalı. `FontFeature.tabularFigures()` bunu sistem fontunda da
  /// verir, çünkü SF Pro sabit genişlikli rakam setini taşır. Böylece
  /// üçüncü bir aile indirmeye gerek kalmıyor.
  static TextStyle mono({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w500,
    Color color = AppColors.charcoal,
    double height = 1.0,
  }) {
    return TextStyle(
      fontFamily: monoFont,
      fontSize: fontSize,
      // DM Mono 500'de bitiyor: daha kalın istenirse sessizce 500 çizilirdi.
      // Sabitlemek, kodun söylediğiyle ekranda görülenin aynı kalmasını
      // sağlıyor.
      fontWeight: fontWeight.value > monoMaxWeight.value
          ? monoMaxWeight
          : fontWeight,
      color: color,
      height: height,
    );
  }

  // ── Adlandırılmış roller — çağrı yerleri BUNLARI kullanır ─────────────────

  /// Ekran adı — `keşfet.` `takip` `adan.` gibi. Handoff'ta serif:
  /// Noto Serif 600, sıkı negatif aralık. Ekran başına punto farkı için
  /// (30 / 28 / 26) `fontSize` geçilebilir.
  static TextStyle screenTitle({required Color color, double? fontSize}) =>
      display(fontSize: fontSize ?? sizeTitle, color: color, height: 1.15);

  /// Ada tasarımının sayfa başlığı ("Takibin", "Günlük", "Sen"): serif 26.
  static TextStyle pageTitle({required Color color, double fontSize = 26}) =>
      display(fontSize: fontSize, color: color, height: 1.2);

  /// Kart/bölüm içindeki serif başlık ("Bir nefeslik mola", "Su").
  static TextStyle serifTitle({required Color color, double fontSize = 20}) =>
      heading(fontSize: fontSize, color: color, height: 1.25);

  /// Liste satırı başlığı: DM Sans kalın 15 (Ada tasarımı satırları).
  static TextStyle rowTitle({required Color color}) => body(
    fontSize: 15,
    color: color,
    height: 1.3,
  ).copyWith(fontWeight: FontWeight.w700);

  /// Kart üstündeki küçük büyük-harf etiket ("BUGÜNÜN KÜÇÜK PRATİĞİ").
  static TextStyle caption({required Color color}) =>
      label(fontSize: 11, color: color, letterSpacingEm: 0.06);

  /// Editoryal an — selamlama, makale başlığı.
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
    // DM Mono'nun en kalın kesimi. Vurgu ağırlıktan değil boyuttan geliyor.
    fontWeight: monoMaxWeight,
    color: color,
  ).copyWith(letterSpacing: -1.2);
}
