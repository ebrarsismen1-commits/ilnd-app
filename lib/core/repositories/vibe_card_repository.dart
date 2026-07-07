import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/services/firebase_service.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

/// Sadece ham veri taşır — bu repository bir [BuildContext]'e erişemez,
/// dolayısıyla yerelleştirilmiş anlatı metnini (headline/subline/hafta
/// aralığı) üretemez. Bu metinler [VibeCardCopy] ile UI katmanında
/// (vibe_card_widget.dart) [AppLocalizations] kullanılarak üretilir.
class VibeCardData {
  const VibeCardData({
    required this.journalCount,
    required this.habitCompletionCount,
    required this.streakDays,
    required this.weekStart,
    required this.weekEnd,
  });

  final int journalCount;
  final int habitCompletionCount;
  final int streakDays;
  final DateTime weekStart;
  final DateTime weekEnd;
}

// ─── Aggregation ──────────────────────────────────────────────────────────────

final vibeCardDataProvider = FutureProvider<VibeCardData?>((ref) async {
  final fbUid = ref.watch(firebaseAuthUidProvider).valueOrNull;
  if (fbUid == null) return null; // köprü girişi bekleniyor
  final auth = ref.watch(authNotifierProvider);
  if (auth is! AuthAuthenticated) return null;

  final uid = auth.user.id;
  final db = FirebaseService.firestore;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekAgo = today.subtract(const Duration(days: 6));
  final weekAgoTs = Timestamp.fromDate(weekAgo);

  final journalFuture = db
      .collection('users')
      .doc(uid)
      .collection('journal_entries')
      .where('createdAt', isGreaterThanOrEqualTo: weekAgoTs)
      .get();

  final dates = List.generate(7, (i) => _fmt(weekAgo.add(Duration(days: i))));
  final habitFuture = db
      .collection('habit_completions')
      .where('userId', isEqualTo: uid)
      .where('date', whereIn: dates)
      .get();

  // Streak: son 60 gün journal_entries üzerinden ardışık aktif gün say.
  final since60 = Timestamp.fromDate(today.subtract(const Duration(days: 60)));
  final streakWindowFuture = db
      .collection('users')
      .doc(uid)
      .collection('journal_entries')
      .where('createdAt', isGreaterThanOrEqualTo: since60)
      .get();

  // Her sorgu bağımsız dayanıklı: biri patlarsa (ör. deploy edilmemiş
  // composite index → FAILED_PRECONDITION) tüm kart yerine yalnız o metrik
  // 0 olur. Aksi halde tek bir alt-sorgu hatası kartı komple çökertip
  // paylaş butonunu kalıcı pasif bırakıyordu (Web Raporu madde 7).
  final results = await Future.wait([
    _safeDocs(journalFuture, 'journal'),
    _safeDocs(habitFuture, 'habit_completions'),
    _safeDocs(streakWindowFuture, 'streak_window'),
  ]);
  final journalDocs = results[0];
  final habitDocs = results[1];
  final streakWindowDocs = results[2];

  final activeDays = streakWindowDocs
      .map((d) {
        final data = d.data() as Map<String, dynamic>?;
        final ts = data?['createdAt'] as Timestamp?;
        if (ts == null) return null;
        final dt = ts.toDate();
        return DateTime(dt.year, dt.month, dt.day);
      })
      .whereType<DateTime>()
      .toSet();

  var streak = 0;
  var check = today;
  while (activeDays.contains(check)) {
    streak++;
    check = check.subtract(const Duration(days: 1));
  }

  final journalCount = journalDocs.length;
  final habitCount = habitDocs.length;

  return VibeCardData(
    journalCount: journalCount,
    habitCompletionCount: habitCount,
    streakDays: streak,
    weekStart: weekAgo,
    weekEnd: today,
  );
});

/// Tek bir Firestore sorgusunu izole eder: hata olursa boş liste döner ki
/// kartın geri kalanı yine üretilebilsin.
Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _safeDocs(
  Future<QuerySnapshot<Map<String, dynamic>>> future,
  String label,
) async {
  try {
    return (await future).docs;
  } catch (e) {
    debugPrint('[VibeCard] $label query failed: $e');
    return const [];
  }
}

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
