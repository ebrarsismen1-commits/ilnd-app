/// Haftalık ve aylık aktivite özeti.
///
/// `profileStatsProvider` 60 günlük veriyi çekip yalnız İÇİNDE BULUNULAN
/// haftayı hesaplıyordu: geçen haftaya bakmanın ya da ayın tamamını görmenin
/// yolu yoktu. Bu dosya aynı ham veriden istenen haftayı ya da ayı üretir.
///
/// Saf: Firestore'u da bugünün tarihini de dışarıdan alır, böylece test
/// edilebilir ve aynı girdi hep aynı çıktıyı verir.
library;

/// Bir günün "aktif" sayılma ölçütü: o gün günlük yazılmış ya da yemek
/// eklenmiş olması. Ölçüt tek yerde durur ki hafta ve ay aynı şeyi saysın.
class ActivityHistory {
  const ActivityHistory({required this.journalDays, required this.foodDays});

  /// Günlük yazılan günler (saat bilgisi olmadan).
  final Set<DateTime> journalDays;

  /// Yemek eklenen günler.
  final Set<DateTime> foodDays;

  Set<DateTime> get activeDays => {...journalDays, ...foodDays};

  static const empty = ActivityHistory(journalDays: {}, foodDays: {});
}

/// Verilen günün içinde bulunduğu haftanın pazartesisi.
DateTime startOfWeek(DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

/// Bir haftanın özeti.
class WeekStats {
  const WeekStats({
    required this.start,
    required this.bars,
    required this.journalCount,
    required this.foodCount,
    required this.activeDayCount,
  });

  /// Haftanın pazartesisi.
  final DateTime start;

  /// Pazartesiden pazara yedi değer: 1.0 aktif, 0.0 değil.
  final List<double> bars;

  final int journalCount;
  final int foodCount;
  final int activeDayCount;

  bool get isEmpty => activeDayCount == 0;
}

/// Bir ayın özeti.
class MonthStats {
  const MonthStats({
    required this.month,
    required this.dayCount,
    required this.activeDays,
    required this.journalCount,
    required this.foodCount,
  });

  /// Ayın ilk günü.
  final DateTime month;

  /// Ayın kaç gün sürdüğü (28-31).
  final int dayCount;

  /// Ayın kaçıncı günlerinde aktivite var (1 tabanlı).
  final Set<int> activeDays;

  final int journalCount;
  final int foodCount;

  int get activeDayCount => activeDays.length;

  /// Aktif gün oranı. Gelecekteki günler paydaya girmez: içinde bulunulan
  /// ayın 3'ündeyken %10 göstermek cesaret kırıcı ve yanlış olurdu.
  double ratioUpTo(DateTime today) {
    final sameMonth = today.year == month.year && today.month == month.month;
    final denominator = sameMonth ? today.day : dayCount;
    if (denominator <= 0) return 0;
    return activeDays.length / denominator;
  }
}

/// [offset] 0 = bu hafta, -1 = geçen hafta.
WeekStats weekStats(
  ActivityHistory history, {
  required DateTime today,
  int offset = 0,
}) {
  final start = startOfWeek(today).add(Duration(days: 7 * offset));
  final active = history.activeDays;
  final normalizedToday = DateTime(today.year, today.month, today.day);

  final bars = List<double>.generate(7, (i) {
    final day = start.add(Duration(days: i));
    // Gelecek günler boş çizilir, "yapılmadı" diye değil "henüz gelmedi".
    if (day.isAfter(normalizedToday)) return 0.0;
    return active.contains(day) ? 1.0 : 0.0;
  });

  int countIn(Set<DateTime> days) => days.where((d) {
    final diff = d.difference(start).inDays;
    return diff >= 0 && diff < 7;
  }).length;

  return WeekStats(
    start: start,
    bars: bars,
    journalCount: countIn(history.journalDays),
    foodCount: countIn(history.foodDays),
    activeDayCount: countIn(active),
  );
}

/// [offset] 0 = bu ay, -1 = geçen ay.
MonthStats monthStats(
  ActivityHistory history, {
  required DateTime today,
  int offset = 0,
}) {
  final month = DateTime(today.year, today.month + offset);
  // Bir sonraki ayın sıfırıncı günü = bu ayın son günü.
  final dayCount = DateTime(month.year, month.month + 1, 0).day;

  Set<int> daysIn(Set<DateTime> days) => days
      .where((d) => d.year == month.year && d.month == month.month)
      .map((d) => d.day)
      .toSet();

  int countIn(Set<DateTime> days) =>
      days.where((d) => d.year == month.year && d.month == month.month).length;

  return MonthStats(
    month: month,
    dayCount: dayCount,
    activeDays: daysIn(history.activeDays),
    journalCount: countIn(history.journalDays),
    foodCount: countIn(history.foodDays),
  );
}
