import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/services/firebase_service.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class ProfileStats {
  const ProfileStats({
    required this.streakDays,
    required this.weeklyJournalCount,
    required this.weeklyFoodCount,
    required this.weeklyActivityByDay, // 7 element: Pt..Pa, 0.0-1.0
  });

  final int streakDays;
  final int weeklyJournalCount;
  final int weeklyFoodCount;
  final List<double> weeklyActivityByDay;

  static const zero = ProfileStats(
    streakDays: 0,
    weeklyJournalCount: 0,
    weeklyFoodCount: 0,
    weeklyActivityByDay: [0, 0, 0, 0, 0, 0, 0],
  );
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final profileStatsProvider = FutureProvider<ProfileStats>((ref) async {
  final auth = ref.watch(authNotifierProvider);
  if (auth is! AuthAuthenticated) return ProfileStats.zero;

  final uid = auth.user.id;
  final db = FirebaseService.firestore;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(Duration(days: today.weekday - 1)); // Pazartesi

  // ── Son 60 günün tarihlerini çek (streak için yeterli) ────────────────────
  final since60 = Timestamp.fromDate(today.subtract(const Duration(days: 60)));

  final journalFuture = db
      .collection('users')
      .doc(uid)
      .collection('journal_entries')
      .where('createdAt', isGreaterThanOrEqualTo: since60)
      .get();

  final foodFuture = db
      .collection('users')
      .doc(uid)
      .collection('food_entries')
      .where('createdAt', isGreaterThanOrEqualTo: since60)
      .get();

  final results = await Future.wait([journalFuture, foodFuture]);
  final journalDocs = results[0].docs;
  final foodDocs = results[1].docs;

  // ── Aktif günleri DateOnly seti olarak topla ──────────────────────────────
  Set<DateTime> activeDays(List<QueryDocumentSnapshot> docs) {
    return docs.map((d) {
      final data = d.data() as Map<String, dynamic>?;
      final ts = data?['createdAt'] as Timestamp?;
      if (ts == null) return null;
      final dt = ts.toDate();
      return DateTime(dt.year, dt.month, dt.day);
    }).whereType<DateTime>().toSet();
  }

  final journalDays = activeDays(journalDocs);
  final foodDays = activeDays(foodDocs);
  final allActiveDays = {...journalDays, ...foodDays};

  // ── Streak: bugünden geriye ardışık gün say ───────────────────────────────
  var streak = 0;
  var check = today;
  while (allActiveDays.contains(check)) {
    streak++;
    check = check.subtract(const Duration(days: 1));
  }

  // ── Bu haftaki (Pzt-bugün) sayılar ───────────────────────────────────────
  final weekEnd = today.add(const Duration(days: 1));
  final weekStartTs = Timestamp.fromDate(weekStart);
  final weekEndTs = Timestamp.fromDate(weekEnd);

  int weeklyJournal = journalDocs.where((d) {
    final data2 = d.data() as Map<String, dynamic>?;
    final ts = data2?['createdAt'] as Timestamp?;
    if (ts == null) return false;
    return ts.compareTo(weekStartTs) >= 0 && ts.compareTo(weekEndTs) < 0;
  }).length;

  int weeklyFood = foodDocs.where((d) {
    final data2 = d.data() as Map<String, dynamic>?;
    final ts = data2?['createdAt'] as Timestamp?;
    if (ts == null) return false;
    return ts.compareTo(weekStartTs) >= 0 && ts.compareTo(weekEndTs) < 0;
  }).length;

  // ── Bar chart: haftanın her günü aktivite var mı? ─────────────────────────
  final barValues = List<double>.generate(7, (i) {
    final day = weekStart.add(Duration(days: i));
    if (day.isAfter(today)) return 0.0;
    final hasActivity = allActiveDays.contains(day);
    return hasActivity ? 1.0 : 0.0;
  });

  return ProfileStats(
    streakDays: streak,
    weeklyJournalCount: weeklyJournal,
    weeklyFoodCount: weeklyFood,
    weeklyActivityByDay: barValues,
  );
});
