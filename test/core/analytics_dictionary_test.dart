import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Analitik sözlüğü (`docs/tr/ANALITIK_SOZLUGU.md`) kodla senkron kalmalı.
///
/// Olayların bir kısmı `AnalyticsService.logEvent('...')` kaçış kapısından
/// serbest metinle gidiyor: adı derleyici doğrulamıyor, yanlış yazım ancak
/// panelde fark ediliyor. Sözlük de aynı sessizlikle bayatlar. Bu test iki
/// yönü de kapatır: kodda olan her olay belgelenmiş olmalı, belgelenen her
/// olay da kodda gerçekten atılıyor olmalı.
///
/// Test kırılıyorsa çözüm sözlüğe satır eklemektir, testi gevşetmek değil.
void main() {
  final libDir = Directory('lib');
  final dictionary = File('docs/tr/ANALITIK_SOZLUGU.md');

  /// `_log('ad'` (servisteki tipli metotlar) ve `logEvent('ad'` (kaçış kapısı).
  final eventPattern = RegExp(r"""\b(?:_log|logEvent)\(\s*'([a-z0-9_]+)'""");

  Set<String> eventsInCode() {
    final found = <String>{};
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final m in eventPattern.allMatches(entity.readAsStringSync())) {
        found.add(m.group(1)!);
      }
    }
    return found;
  }

  /// Sözlükteki tablo satırlarının ilk hücresi olay adıdır.
  ///
  /// Kasten tablo satırı aranıyor, düz metin değil: bir olayın adı açıklama
  /// cümlesinde geçiyor diye belgelenmiş sayılmamalı, kendi satırı olmalı.
  Set<String> eventsInDoc(String doc) => RegExp(
    r'^\|\s*`([a-z0-9_]+)`\s*\|',
    multiLine: true,
  ).allMatches(doc).map((m) => m.group(1)!).toSet();

  test('sözlük dosyası duruyor', () {
    expect(
      dictionary.existsSync(),
      isTrue,
      reason: 'docs/tr/ANALITIK_SOZLUGU.md bulunamadı',
    );
  });

  test('kodda atılan her olay sözlükte kendi satırıyla belgeli', () {
    final events = eventsInCode();
    final documented = eventsInDoc(dictionary.readAsStringSync());

    // Tarama bozulursa (desen kayarsa) test sessizce yeşil kalmasın.
    expect(
      events.length,
      greaterThan(20),
      reason: 'olay taraması az sonuç verdi, desen bozulmuş olabilir',
    );
    expect(documented.length, greaterThan(20));

    final undocumented = events.difference(documented).toList()..sort();

    expect(
      undocumented,
      isEmpty,
      reason:
          'Kodda var ama sözlükte satırı yok: ${undocumented.join(', ')}. '
          'docs/tr/ANALITIK_SOZLUGU.md dosyasına satır ekle.',
    );
  });

  test('sözlükteki her olay kodda gerçekten atılıyor', () {
    final events = eventsInCode();
    final documented = eventsInDoc(dictionary.readAsStringSync());

    // Firebase'in yerleşik olayı; literal adı kodda geçmez.
    const builtIn = {'app_open'};

    final stale = documented.difference(events).difference(builtIn).toList()
      ..sort();

    expect(
      stale,
      isEmpty,
      reason:
          'Sözlükte var ama kodda atılmıyor: ${stale.join(', ')}. '
          'Olay kaldırıldıysa sözlükten de çıkar.',
    );
  });
}
