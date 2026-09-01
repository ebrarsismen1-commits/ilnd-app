import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/theme/app_text_styles.dart';

/// Tipografi koruması.
///
/// Tarihçe: 2026-08-11 denetiminde kod tabanında 33 ayrı `fontSize` vardı ve
/// her çağrı yeri kendi sayısını uyduruyordu — "her ekranda farklı yazı tipi
/// varmış gibi" hissinin sebebi buydu. O zaman ölçek 10 role indirilip sert
/// bir testle kilitlenmişti.
///
/// 2026-08-18 tasarım handoff'u ekran başına kendi puntolarını getirdiği için
/// (owner kararı: handoff birebir uygulanacak) o kilit kalktı. Yerine iki
/// daha zayıf ama hâlâ işe yarayan koruma var:
///
/// 1. **İndirme yasağı** — 2026-08-31'de üç aile de (Noto Serif, DM Sans,
///    DM Mono) pakete gömüldü. Artık lib/ içinde hiç GoogleFonts çağrısı
///    olmamalı, ve gömülü dosyaların yerinde ve geçerli olduğu ayrıca
///    doğrulanıyor: ikisinden biri kaçarsa metin sessizce sistem fontuna
///    kayar.
/// 2. **Ölçek kümesi** — puntolar handoff'un belgelenmiş kümesinden gelmeli.
///    Serbest bırakılan şey ölçeğin genişliği, keyfîliği değil: rastgele bir
///    37 hâlâ kırılır.
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      // Üretilen l10n dosyaları taranmaz.
      .where((f) => !f.path.contains('app_localizations'))
      .toList();

  test('lib/ çalışma anında font İNDİRMEZ', () {
    // 2026-08-31: üç aile de pakete gömüldü, artık lib/ içinde hiç
    // GoogleFonts çağrısı olmamalı.
    //
    // Bu yalnız bir stil kuralı değil: indirilen font, ağsız ilk açılışta
    // sistem fontuna düşer. Uygulama açılır, hiçbir hata görünmez, sadece
    // kimliği kaybolur. App Store incelemesi de aynı riski taşır.
    final pattern = RegExp(r'GoogleFonts\.([a-zA-Z]+)\(');
    final offenders = <String>[];

    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final m in pattern.allMatches(lines[i])) {
          offenders.add('${file.path}:${i + 1} → ${m.group(1)}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'lib/ içinde GoogleFonts çağrısı var. Üç aile de pakete gömülü: '
          'AppTextStyles.serifFont / sansFont / monoFont kullan. '
          'İhlaller: ${offenders.join(', ')}',
    );
  });

  test('üç aile de pakete gömülü ve dosyaları geçerli', () {
    // Kilidin ikinci yarısı: çağrı doğru olsa da asset düşerse metin
    // sessizce sistem fontuna kayar.
    final pubspec = File('pubspec.yaml').readAsStringSync();

    const bundled = <String, List<String>>{
      'NotoSerif': ['Regular', 'SemiBold'],
      'DMSans': ['Regular', 'Medium', 'SemiBold', 'Bold'],
      // DM Mono 500'de bitiyor; 600/700 kesimi ÜRETİLMEMİŞ.
      'DMMono': ['Medium'],
    };

    for (final family in bundled.entries) {
      expect(
        pubspec,
        contains('family: ${family.key}'),
        reason: 'pubspec.yaml ${family.key} ailesini bildirmiyor',
      );

      for (final cut in family.value) {
        final path = 'assets/fonts/${family.key}-$cut.ttf';
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path yok');
        expect(
          pubspec,
          contains(path),
          reason: '$path pubspec.yaml içinde bildirilmemiş',
        );
        // TrueType imzası: 0x00010000. EOT/WOFF yanlışlıkla indirilirse
        // Flutter fontu sessizce yok sayar (bir kez yaşandı: Google Fonts
        // eski tarayıcı UA'sına EOT döndürüyor).
        final head = file.readAsBytesSync().take(4).toList();
        expect(head, [0, 1, 0, 0], reason: '$path geçerli bir TTF değil');
      }
    }
  });

  test('sayı stilleri DM Mono nun üst ağırlığını aşmaz', () {
    // DM Mono 500'ün üstünde kesim taşımıyor. Daha kalın istenirse Flutter
    // sessizce en yakınına düşer, yani kod 700 der ekran 500 çizer.
    // `mono()` bu yüzden ağırlığı kırpıyor; kırpma kalkarsa burada görülür.
    expect(AppTextStyles.monoMaxWeight, FontWeight.w500);

    final clamped = AppTextStyles.mono(
      color: const Color(0xFF000000),
      fontWeight: FontWeight.w900,
    );
    expect(
      clamped.fontWeight,
      FontWeight.w500,
      reason: 'var olmayan bir kesim istenirse ağırlık kırpılmalı',
    );
    expect(clamped.fontFamily, AppTextStyles.monoFont);

    // Kalori/streak kahramanı da aynı tavanda.
    expect(
      AppTextStyles.metric(color: const Color(0xFF000000)).fontWeight,
      FontWeight.w500,
    );
  });

  test('fontSize değerleri handoff ölçeğinden gelir', () {
    // Handoff'un (design_handoff_ilnd_redesign/README.md) belgelediği punto
    // kümesi. Yeni bir boyut gerçekten gerekiyorsa önce buraya eklenir ve
    // gerekçesi commit mesajına yazılır.
    final handoff = <double>{
      8.5, 9, 9.5, 10, 10.5, 11, 11.5, 12, 12.5, 13, 13.5, 14, 14.5, 15, //
      15.5, 16, 16.5, 17, 18, 19, 20, 22, 24, 26, 28, 29, 30, 31, 32, 34, //
      42, 56,
    };
    // Handoff öncesinden kalan iki metrik boyutu (AppTextStyles.sizeMetric*).
    // İlgili ekranlar handoff'a çevrildikçe bu ikisi listeden düşecek.
    final legacy = <double>{40, 44};

    final allowed = {...handoff, ...legacy};
    final pattern = RegExp(r'fontSize:\s*([0-9]+(?:\.[0-9]+)?)');
    final offenders = <String>[];

    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final m in pattern.allMatches(lines[i])) {
          final value = double.parse(m.group(1)!);
          if (!allowed.contains(value)) {
            offenders.add('${file.path}:${i + 1} → $value');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Handoff ölçeği dışında ${offenders.length} punto var.\n'
          '${offenders.take(40).join('\n')}',
    );
  });
}
