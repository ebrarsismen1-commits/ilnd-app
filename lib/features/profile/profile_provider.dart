import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/features/profile/activity_stats.dart';
import 'package:ilnd_app/core/services/firebase_service.dart';
import 'package:ilnd_app/core/services/streak_tracker.dart';
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

/// Aktivite geçmişinin çekildiği TEK yer.
///
/// Hem haftalık/aylık gezinme hem de [profileStatsProvider] bunu paylaşır;
/// eskiden yalnız stats vardı ve her ekran açılışında kendi sorgusunu
/// atıyordu. Pencere 120 gün: seri 60 gün yetiyor ama ay gezinmesi için
/// daha geriye bakmak gerekiyor.
const int kActivityWindowDays = 120;

final activityHistoryProvider = FutureProvider<ActivityHistory>((ref) async {
  final fbUid = ref.watch(firebaseAuthUidProvider).valueOrNull;
  if (fbUid == null) return ActivityHistory.empty; // köprü girişi bekleniyor
  final auth = ref.watch(authNotifierProvider);
  if (auth is! AuthAuthenticated) return ActivityHistory.empty;

  final uid = auth.user.id;
  final db = FirebaseService.firestore;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final since = Timestamp.fromDate(
    today.subtract(const Duration(days: kActivityWindowDays)),
  );

  Future<QuerySnapshot<Map<String, dynamic>>> fetch(String col) => db
      .collection('users')
      .doc(uid)
      .collection(col)
      .where('createdAt', isGreaterThanOrEqualTo: since)
      .get();

  final results = await Future.wait([
    fetch('journal_entries'),
    fetch('food_entries'),
  ]);

  Set<DateTime> days(QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
      .map((d) {
        final ts = (d.data())['createdAt'] as Timestamp?;
        if (ts == null) return null;
        final dt = ts.toDate();
        return DateTime(dt.year, dt.month, dt.day);
      })
      .whereType<DateTime>()
      .toSet();

  return ActivityHistory(
    journalDays: days(results[0]),
    foodDays: days(results[1]),
  );
});

/// [offset] 0 = bu hafta, -1 = geçen hafta.
final weekStatsProvider = Provider.family<WeekStats, int>((ref, offset) {
  final history =
      ref.watch(activityHistoryProvider).valueOrNull ?? ActivityHistory.empty;
  return weekStats(history, today: DateTime.now(), offset: offset);
});

/// [offset] 0 = bu ay, -1 = geçen ay.
final monthStatsProvider = Provider.family<MonthStats, int>((ref, offset) {
  final history =
      ref.watch(activityHistoryProvider).valueOrNull ?? ActivityHistory.empty;
  return monthStats(history, today: DateTime.now(), offset: offset);
});

/// Kaç hafta/ay geriye gidilebilir. Pencerenin dışına çıkan bir ekran boş
/// veri gösterir ve kullanıcı bunu "kayıtlarım silinmiş" diye okur.
int get maxWeeksBack => kActivityWindowDays ~/ 7 - 1;
int get maxMonthsBack => kActivityWindowDays ~/ 31;

final profileStatsProvider = FutureProvider<ProfileStats>((ref) async {
  final history = await ref.watch(activityHistoryProvider.future);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final active = history.activeDays;

  // Seri: bugünden geriye ardışık gün say.
  var streak = 0;
  var check = today;
  while (active.contains(check)) {
    streak++;
    check = check.subtract(const Duration(days: 1));
  }

  final week = weekStats(history, today: today);
  unawaited(ref.read(longestStreakProvider.notifier).observe(streak));

  return ProfileStats(
    streakDays: streak,
    weeklyJournalCount: week.journalCount,
    weeklyFoodCount: week.foodCount,
    weeklyActivityByDay: week.bars,
  );
});
