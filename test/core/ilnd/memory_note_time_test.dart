import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hafıza notlarının zamanı.
///
/// Notlar zamansız düz metindi ve prompt'a "Son notlar: ..." diye giriyordu.
/// Model iki hafta önce yenen bir eriği dünkünden ayıramıyordu ve ILND
/// "bugün erikler nasıldı" diye sordu (2026-08-31). Sorun modelde değil, ona
/// verilen bağlamdaydı.
void main() {
  final now = DateTime(2026, 9, 2, 12);

  MemoryNote noteDaysAgo(int days, [String text = 'Yemek: Erik']) =>
      MemoryNote(text, at: now.subtract(Duration(days: days)));

  group('notun yaşı', () {
    test('gün farkı saatten bağımsız hesaplanır', () {
      // Dün 23:00 ile bugün 01:00 arası 2 saat ama bir gün farkı.
      final dun = MemoryNote('x', at: DateTime(2026, 9, 1, 23));
      expect(dun.ageInDays(DateTime(2026, 9, 2, 1)), 1);
    });

    test('zaman ifadesi insanca yazılır', () {
      expect(noteDaysAgo(0).whenLabel(now), 'bugün');
      expect(noteDaysAgo(1).whenLabel(now), 'dün');
      expect(noteDaysAgo(3).whenLabel(now), '3 gün önce');
      expect(noteDaysAgo(9).whenLabel(now), 'geçen hafta');
      expect(noteDaysAgo(30).whenLabel(now), 'birkaç hafta önce');
    });

    test('tarihsiz not "daha önce" der, bugün demez', () {
      const undated = MemoryNote('x');
      expect(undated.ageInDays(now), isNull);
      expect(undated.whenLabel(now), 'daha önce');
    });
  });

  group('prompt bağlamı', () {
    test('her notun önüne zamanı yazılır', () {
      final memory = IlndMemory(
        recentNotes: [noteDaysAgo(0, 'Yemek: Çorba'), noteDaysAgo(1)],
      );
      final ctx = memory.toPromptContext(now: now);

      expect(ctx, contains('bugün: Yemek: Çorba'));
      expect(ctx, contains('dün: Yemek: Erik'));
      expect(
        ctx,
        isNot(contains('Son notlar')),
        reason: 'eski başlık her notu güncel gösteriyordu',
      );
    });

    test('bayat notlar prompta hiç girmez', () {
      final memory = IlndMemory(
        recentNotes: [
          noteDaysAgo(IlndMemory.noteFreshnessDays + 1),
          noteDaysAgo(0, 'Yemek: Çorba'),
        ],
      );
      final ctx = memory.toPromptContext(now: now);

      expect(ctx, contains('Çorba'));
      expect(
        ctx,
        isNot(contains('Erik')),
        reason: 'iki haftadan eski öğün bağlam değil gürültü',
      );
    });

    test('tarihsiz eski kayıtlar da elenir', () {
      // Zaman damgası öncesinden kalan notlar: ne zaman olduklarını
      // söyleyemediğimiz için modele verilemez.
      const memory = IlndMemory(recentNotes: [MemoryNote('Yemek: Erik')]);
      expect(memory.toPromptContext(), isNot(contains('Erik')));
    });

    test('hiç taze not yoksa not bölümü hiç yazılmaz', () {
      final memory = IlndMemory(recentNotes: [noteDaysAgo(60)]);
      expect(memory.toPromptContext(now: now), isNot(contains('Notlar')));
    });
  });

  group('kalıcılık', () {
    test('zaman damgası kaydedilip geri okunur', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final a = IlndMemoryNotifier(prefs, '', 'u1');
      await a.addNote('Yemek: Erik');

      final b = IlndMemoryNotifier(prefs, '', 'u1');
      expect(b.state.recentNotes.single.text, 'Yemek: Erik');
      expect(
        b.state.recentNotes.single.at,
        isNotNull,
        reason: 'not tarihsiz kaydedilirse hata geri gelir',
      );
    });

    test('eski biçimdeki (düz dize) notlar kaybolmaz', () {
      // Göç: zaman damgasından önce yazılmış kayıtlar okunmaya devam eder,
      // yalnız tarihsiz kalır ve prompta girmez.
      final memory = IlndMemory.fromJson(const {
        'name': 'Ela',
        'recentNotes': ['Yemek: Erik', 'Kullanıcı: merhaba'],
      });

      expect(memory.recentNotes, hasLength(2));
      expect(memory.recentNotes.first.text, 'Yemek: Erik');
      expect(memory.recentNotes.first.at, isNull);
      expect(memory.toPromptContext(now: now), isNot(contains('Erik')));
    });

    test('yeni biçim tam tur döner', () {
      final original = IlndMemory(recentNotes: [noteDaysAgo(1)]);
      final restored = IlndMemory.fromJson(original.toJson());

      expect(
        restored.recentNotes.single.text,
        original.recentNotes.single.text,
      );
      expect(restored.recentNotes.single.at, original.recentNotes.single.at);
    });
  });
}
