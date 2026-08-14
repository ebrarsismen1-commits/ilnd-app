import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/theme/app_text_styles.dart';

/// Denetim (2026-08-11): kod tabaninda 33 ayri `fontSize` vardi — her cagri
/// yeri kendi sayisini uyduruyordu. Ekranlar arasi "farkli yazi tipi varmis
/// gibi" hissinin sebebi buydu: font ayniydi, OLCEK dagitikti.
///
/// Bu test olcegin yeniden dagilmasini engeller: `lib/` icinde kullanilan her
/// `fontSize` degeri, AppTextStyles'ta tanimli olceklerden biri olmali.
void main() {
  final allowed = <double>{
    AppTextStyles.sizeHero,
    AppTextStyles.sizeTitle,
    AppTextStyles.sizeHeadline,
    AppTextStyles.sizeTitle3,
    AppTextStyles.sizeBody,
    AppTextStyles.sizeCallout,
    AppTextStyles.sizeFootnote,
    AppTextStyles.sizeCaption,
    AppTextStyles.sizeMetric,
    AppTextStyles.sizeMetricLarge,
  };

  test('tip olcegi 10 rolden ibaret ve degerler tekil', () {
    expect(allowed.length, 10, reason: 'Ayni deger iki role atanmis olmamali');
    // Ölçek artan sırada ve makul aralıklarla olmalı.
    final sorted = allowed.toList()..sort();
    expect(sorted.first, lessThan(sorted.last));
  });

  test('lib/ icinde ciplak fontSize kullanimi olcek disina cikmamali', () {
    final offenders = <String>[];
    final pattern = RegExp(r'fontSize:\s*([0-9]+(?:\.[0-9]+)?)');

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // Ölçeğin kendisi ve üretilen l10n dosyaları hariç.
      if (entity.path.contains('app_text_styles.dart')) continue;
      if (entity.path.contains(['l10n', 'app_localizations'].join(''))) {
        continue;
      }

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final m in pattern.allMatches(lines[i])) {
          final value = double.parse(m.group(1)!);
          if (!allowed.contains(value)) {
            offenders.add('${entity.path}:${i + 1} → $value');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Olcek disi ${offenders.length} kullanim var. Cozum: AppTextStyles\n'
          'rollerinden birini kullan (screenTitle/cardTitle/bodyText/callout/\n'
          'footnote/metric...). Gercekten yeni bir boyut gerekiyorsa once\n'
          'AppTextStyles\'a ekle.\n\n${offenders.take(40).join('\n')}',
    );
  });
}
