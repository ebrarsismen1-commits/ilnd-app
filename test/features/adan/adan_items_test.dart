import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/features/adan/adan_model.dart';

/// ADR-0006 §2: eşik tablosu iki yerde duruyor — kazanım kararını veren
/// `functions/index.js` (`ISLAND_ITEMS`) ve yalnız gösterim için tutulan
/// `adan_model.dart` (`kIslandItems`). İkisi ayrışırsa kullanıcıya "3 gün
/// seri" yazarken sunucu 5 günde verir; kimse fark etmez.
///
/// Bu test ayrışmayı CI'da kırar. Yeni öğe İKİ dosyaya birden eklenir.
void main() {
  test('istemci ve sunucu eşik tabloları birebir aynı', () {
    final js = File('functions/index.js').readAsStringSync();
    final start = js.indexOf('const ISLAND_ITEMS = [');
    expect(start, isNot(-1), reason: 'ISLAND_ITEMS sunucuda bulunamadı');
    final end = js.indexOf('];', start);
    final block = js.substring(start, end);

    // {id: "lantern", metric: "journalCount", threshold: 1, ...}
    final entry = RegExp(
      r'\{id:\s*"([a-zA-Z]+)",\s*metric:\s*"([a-zA-Z]+)",\s*'
      r'threshold:\s*(\d+),\s*\n?\s*serverVerifiable:\s*(true|false)',
      multiLine: true,
    );
    final serverItems = entry
        .allMatches(block)
        .map(
          (m) => (
            id: m.group(1)!,
            metric: m.group(2)!,
            threshold: int.parse(m.group(3)!),
            verifiable: m.group(4) == 'true',
          ),
        )
        .toList();

    expect(
      serverItems.length,
      kIslandItems.length,
      reason:
          'Sunucuda ${serverItems.length}, istemcide ${kIslandItems.length} '
          'öğe var. Yeni öğe iki dosyaya birden eklenir.',
    );

    for (var i = 0; i < kIslandItems.length; i++) {
      final client = kIslandItems[i];
      final server = serverItems[i];
      expect(server.id, client.id, reason: '$i. öğenin kimliği ayrışmış');
      expect(
        server.threshold,
        client.threshold,
        reason: '${client.id}: eşik ayrışmış',
      );
      expect(
        server.metric,
        client.metric.name,
        reason: '${client.id}: ölçüt ayrışmış',
      );
      expect(
        server.verifiable,
        client.serverVerifiable,
        reason: '${client.id}: doğrulanabilirlik ayrışmış',
      );
    }
  });

  group('IslandState', () {
    test('sıradaki öğe yalnız sunucudan doğrulanabilir olanlardan seçilir', () {
      // Dördü de kazanılmışsa sırada kilitli öğeler VAR ama onlar hiç
      // kazanılamaz — "sıradaki" diye onları göstermek boş söz olurdu.
      const all = IslandState(earned: {'lantern', 'pine', 'oven', 'windrose'});
      expect(all.nextItem, isNull);
    });

    test('boş adada sıradaki öğe ilk kazanılabilir öğedir', () {
      const empty = IslandState();
      expect(empty.nextItem?.id, 'lantern');
      expect(empty.earnedCount, 0);
    });

    test('kazanılmış öğe sayılır ve sorgulanabilir', () {
      const s = IslandState(earned: {'lantern', 'pine'});
      expect(s.earnedCount, 2);
      expect(s.has('lantern'), isTrue);
      expect(s.has('oven'), isFalse);
      expect(s.nextItem?.id, 'oven');
    });
  });
}
