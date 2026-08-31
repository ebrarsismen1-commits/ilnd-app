import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/features/profile/activity_stats.dart';

/// Haftalık ve aylık aktivite özeti.
///
/// Eskiden yalnız içinde bulunulan hafta hesaplanıyordu; geçen haftaya
/// bakmanın ya da ayın tamamını görmenin yolu yoktu.
void main() {
  // 2026-09-02 bir çarşamba. Haftanın pazartesisi 2026-08-31.
  final today = DateTime(2026, 9, 2);

  DateTime d(int year, int month, int day) => DateTime(year, month, day);

  ActivityHistory history({Set<DateTime>? journal, Set<DateTime>? food}) =>
      ActivityHistory(
        journalDays: journal ?? const {},
        foodDays: food ?? const {},
      );

  group('haftanın başı', () {
    test('pazartesi bulunur, gün ortasından bağımsız', () {
      expect(startOfWeek(DateTime(2026, 9, 2, 23, 30)), d(2026, 8, 31));
      expect(startOfWeek(d(2026, 8, 31)), d(2026, 8, 31));
      // Pazar haftanın SONU: kendi haftasının pazartesisine bakar.
      expect(startOfWeek(d(2026, 9, 6)), d(2026, 8, 31));
      expect(startOfWeek(d(2026, 9, 7)), d(2026, 9, 7));
    });
  });

  group('hafta', () {
    test('bu hafta ve geçen hafta ayrı sayılır', () {
      final h = history(
        journal: {d(2026, 9, 1), d(2026, 8, 26)},
        food: {d(2026, 9, 2)},
      );

      final bu = weekStats(h, today: today);
      expect(bu.start, d(2026, 8, 31));
      expect(bu.journalCount, 1, reason: '1 Eylül bu haftaya düşer');
      expect(bu.foodCount, 1);
      expect(bu.activeDayCount, 2);

      final gecen = weekStats(h, today: today, offset: -1);
      expect(gecen.start, d(2026, 8, 24));
      expect(gecen.journalCount, 1, reason: '26 Ağustos geçen haftaya düşer');
      expect(gecen.foodCount, 0);
    });

    test('çubuklar pazartesiden pazara dizilir', () {
      // 1 Eylül salı → indeks 1.
      final h = history(journal: {d(2026, 9, 1)});
      final bars = weekStats(h, today: today).bars;

      expect(bars.length, 7);
      expect(bars[1], 1.0);
      expect(bars[0], 0.0);
    });

    test('gelecek günler boş çizilir, "yapılmadı" diye değil', () {
      // Bugün çarşamba; perşembe-pazar henüz gelmedi.
      final h = history(journal: {d(2026, 9, 2)});
      final bars = weekStats(h, today: today).bars;

      expect(bars[2], 1.0, reason: 'çarşamba aktif');
      for (var i = 3; i < 7; i++) {
        expect(bars[i], 0.0, reason: 'gelecek gün dolu görünmemeli');
      }
    });

    test('aynı gün hem günlük hem yemek varsa bir aktif gün sayılır', () {
      final h = history(journal: {d(2026, 9, 1)}, food: {d(2026, 9, 1)});
      final w = weekStats(h, today: today);

      expect(w.journalCount, 1);
      expect(w.foodCount, 1);
      expect(w.activeDayCount, 1, reason: 'gün sayısı, kayıt sayısı değil');
    });

    test('hiç aktivite yoksa hafta boş', () {
      expect(weekStats(ActivityHistory.empty, today: today).isEmpty, isTrue);
    });
  });

  group('ay', () {
    test('ay uzunluğu doğru hesaplanır', () {
      expect(
        monthStats(ActivityHistory.empty, today: d(2026, 9, 15)).dayCount,
        30,
      );
      expect(
        monthStats(ActivityHistory.empty, today: d(2026, 8, 15)).dayCount,
        31,
      );
      expect(
        monthStats(ActivityHistory.empty, today: d(2026, 2, 15)).dayCount,
        28,
      );
      // 2028 artık yıl.
      expect(
        monthStats(ActivityHistory.empty, today: d(2028, 2, 15)).dayCount,
        29,
      );
    });

    test('yalnız o ayın günleri sayılır', () {
      final h = history(
        journal: {d(2026, 9, 1), d(2026, 8, 31)},
        food: {d(2026, 9, 20)},
      );
      final eylul = monthStats(h, today: today);

      expect(eylul.activeDays, {1, 20});
      expect(eylul.journalCount, 1);
      expect(eylul.foodCount, 1);
    });

    test('geçen aya bakılabilir', () {
      final h = history(journal: {d(2026, 8, 31), d(2026, 8, 3)});
      final agustos = monthStats(h, today: today, offset: -1);

      expect(agustos.month, d(2026, 8, 1));
      expect(agustos.activeDays, {3, 31});
    });

    test('yıl sınırını geçer', () {
      final ocak = monthStats(ActivityHistory.empty, today: d(2026, 1, 10));
      final aralik = monthStats(
        ActivityHistory.empty,
        today: d(2026, 1, 10),
        offset: -1,
      );
      expect(ocak.month, d(2026, 1, 1));
      expect(aralik.month, d(2025, 12, 1));
      expect(aralik.dayCount, 31);
    });

    test('içinde bulunulan ayda oran bugüne kadar hesaplanır', () {
      // Ayın 2'sindeyiz ve 1 gün aktif. Payda 30 olsaydı %3 çıkardı;
      // doğrusu 1/2. Gelecek günleri "kaçırılmış" saymak cesaret kırıcı.
      final h = history(journal: {d(2026, 9, 1)});
      final eylul = monthStats(h, today: today);

      expect(eylul.ratioUpTo(today), 0.5);
    });

    test('geçmiş ayda oran ayın tamamına göre hesaplanır', () {
      final h = history(journal: {d(2026, 8, 1), d(2026, 8, 2)});
      final agustos = monthStats(h, today: today, offset: -1);

      expect(agustos.ratioUpTo(today), 2 / 31);
    });
  });
}
