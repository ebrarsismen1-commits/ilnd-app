import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/services/firebase_service.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';

const _kWeeklyCheckinCacheCount = 'weekly_checkin_cache_count';
const _kWeeklyCheckinCacheAt = 'weekly_checkin_cache_at';
const _cacheTtl = Duration(hours: 1);

/// Anonim sosyal kanıt için hafif bir aktivite kaydı — kullanıcı bazlı,
/// günde tek doküman (deterministik id sayesinde idempotent). Toplam
/// benzersiz aktif kullanıcı sayısını saymak collectionGroup sorgusu veya
/// ayrı bir index gerektirmesin diye kök seviyede tek koleksiyon kullanılır.
abstract final class CheckinRepository {
  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseService.firestore.collection('daily_checkins');

  /// Kullanıcının bugün aktif olduğunu işaretler. Vanity bir metrik
  /// olduğu için sessizce başarısız olabilir, ana akışı bloklamaz.
  static Future<void> markActiveToday(String userId) async {
    final today = _fmt(DateTime.now());
    try {
      await _col.doc('${userId}_$today').set({
        'userId': userId,
        'date': today,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // sessizce yut
    }
  }

  /// Son 7 gün içinde aktif olan benzersiz kullanıcı sayısı.
  static Future<int> weeklyActiveCount() async {
    final dates = List.generate(
      7,
      (i) => _fmt(DateTime.now().subtract(Duration(days: i))),
    );
    final agg = await _col.where('date', whereIn: dates).count().get();
    return agg.count ?? 0;
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Haftalık aktif kullanıcı sayısı — ~1 saat client-side cache ile.
/// Sorgu başarısız olursa eski cache değeri (varsa) gösterilir.
final weeklyCheckinCountProvider = FutureProvider<int?>((ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  final cachedAt = prefs.getInt(_kWeeklyCheckinCacheAt);
  final cachedCount = prefs.getInt(_kWeeklyCheckinCacheCount);

  if (cachedAt != null && cachedCount != null) {
    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(cachedAt),
    );
    if (age < _cacheTtl) return cachedCount;
  }

  try {
    final count = await CheckinRepository.weeklyActiveCount();
    await prefs.setInt(_kWeeklyCheckinCacheCount, count);
    await prefs.setInt(
      _kWeeklyCheckinCacheAt,
      DateTime.now().millisecondsSinceEpoch,
    );
    return count;
  } catch (_) {
    return cachedCount;
  }
});
