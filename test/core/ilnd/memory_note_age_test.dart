import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hafıza notları zamansızdı: kullanıcı bir hafta önce erik eklemişti, ILND
/// bugün "sabah yediğin erik" dedi. Not doğruydu, zamanı yoktu. Ürünün en
/// ayırt edici parçası hatırlamak olduğu için yanlış hatırlamak, hiç
/// hatırlamamaktan daha çok zarar veriyor; o yüzden testle kilitleniyor.
void main() {
  final bugun = DateTime(2026, 9, 1);

  group('Not zaman etiketi', () {
    test('bir haftalık not bugüne çekilmez', () {
      const note = MemoryNote('Yemek: erik (30 kcal)', day: '2026-08-25');
      expect(note.ageLabel(now: bugun), '1 hafta önce');

      final ctx = const IlndMemory(
        recentNotes: [note],
      ).toPromptContext(now: bugun);
      expect(ctx, contains('[1 hafta önce] Yemek: erik (30 kcal)'));
      expect(ctx, isNot(contains('[bugün]')));
    });

    test('bugün, dün ve gün sayısı ayrı ayrı etiketlenir', () {
      String label(String day) => MemoryNote('x', day: day).ageLabel(now: bugun);
      expect(label('2026-09-01'), 'bugün');
      expect(label('2026-08-31'), 'dün');
      expect(label('2026-08-29'), '3 gün önce');
      expect(label('2026-08-04'), '4 hafta önce');
      expect(label('2026-06-01'), '3 ay önce');
    });

    test('tarihi olmayan nota tarih uydurulmaz', () {
      const note = MemoryNote('Yemek: erik (30 kcal)');
      expect(note.ageLabel(now: bugun), 'tarihi belirsiz');
      expect(
        const IlndMemory(recentNotes: [note]).toPromptContext(now: bugun),
        contains('[tarihi belirsiz]'),
      );
    });
  });

  group('Kalıcılık', () {
    test('addNote notu bugünün günüyle damgalar', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final memory = IlndMemoryNotifier(prefs, '', 'user-1');
      await memory.addNote('Yemek: erik (30 kcal)', at: bugun);

      expect(memory.state.recentNotes.single.day, '2026-09-01');
      expect(memory.state.recentNotes.single.ageLabel(now: bugun), 'bugün');

      // Diskte de tarihiyle durur: yeniden kurulan notifier onu okur.
      final again = IlndMemoryNotifier(prefs, '', 'user-1');
      expect(again.state.recentNotes.single.day, '2026-09-01');
    });

    test('eski düz metin notlar silinmez, tarihsiz okunur', () async {
      SharedPreferences.setMockInitialValues({
        'ilnd_memory_user-1': jsonEncode({
          'name': 'Ela',
          'goals': <String>[],
          'facts': <String>[],
          'recentNotes': ['Yemek: erik (30 kcal)'],
        }),
      });
      final prefs = await SharedPreferences.getInstance();

      final memory = IlndMemoryNotifier(prefs, '', 'user-1');
      expect(memory.state.recentNotes.single.text, 'Yemek: erik (30 kcal)');
      expect(memory.state.recentNotes.single.day, isEmpty);
      expect(
        memory.state.toPromptContext(now: bugun),
        contains('[tarihi belirsiz]'),
      );
    });
  });
}
