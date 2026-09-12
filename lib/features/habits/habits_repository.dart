import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ilnd_app/core/repositories/checkin_repository.dart';
import 'package:ilnd_app/features/habits/habit_model.dart';

class HabitsRepository {
  final _db = FirebaseFirestore.instance;

  // ── Habits ──────────────────────────────────────────────────────────────────

  Stream<List<Habit>> habitsStream(String userId) => _db
      .collection('habits')
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt')
      .withConverter<Habit>(
        fromFirestore: (snap, _) => Habit.fromFirestore(snap),
        toFirestore: (h, _) => h.toFirestore(),
      )
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());

  Future<void> addHabit(String userId, String name, int targetDaysPerWeek) =>
      _db.collection('habits').add({
        'userId': userId,
        'name': name,
        'targetDaysPerWeek': targetDaysPerWeek,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteHabit(String habitId) =>
      _db.collection('habits').doc(habitId).delete();

  // ── Completions ──────────────────────────────────────────────────────────────

  // Returns the set of habit IDs completed on a given date (YYYY-MM-DD).
  Stream<Set<String>> completionsStream(String userId, String date) => _db
      .collection('habit_completions')
      .where('userId', isEqualTo: userId)
      .where('date', isEqualTo: date)
      .snapshots()
      .map((s) => s.docs.map(_completionHabitId).whereType<String>().toSet());

  /// Bozuk bir doküman (eksik/yanlış tipte alan) tüm akışı düşürmesin: eskiden
  /// `d['habitId'] as String` fırlatıyor, takip ekranı kalıcı hataya
  /// düşüyordu (güvenlik denetimi H-1). Geçersiz kayıt atlanır.
  static String? _completionHabitId(DocumentSnapshot<Map<String, dynamic>> d) {
    final v = (d.data() ?? const <String, dynamic>{})['habitId'];
    return v is String ? v : null;
  }

  // Returns completions for the last 7 days: { 'YYYY-MM-DD': { habitId, ... } }
  Stream<Map<String, Set<String>>> last7DaysStream(String userId) =>
      completionsRangeStream(userId, 7);

  /// Son [days] günün tamamlamaları: { 'YYYY-MM-DD': { habitId, ... } }.
  ///
  /// `whereIn` yerine tarih aralığı kullanılıyor: hafta görünümü için 7 değer
  /// sorun değildi ama ay görünümü `whereIn`'in 30 değer tavanına dayanıyor ve
  /// bir gün daha eklemek sorguyu sessizce patlatırdı. YYYY-MM-DD dizesinde
  /// sözlüksel sıra takvim sırasıyla aynı olduğu için `>=` karşılaştırması
  /// güvenli; sorgu zaten var olan (userId, date) indeksini kullanır.
  ///
  /// [endDay] verilirse pencere o günde biter: takip ekranı geçmiş bir güne
  /// gidince ızgaranın son hücresi bugün değil, bakılan gündür — pencere de
  /// onunla birlikte geriye kayar. Üst sınır sorguya konmaz (sonraki günlerin
  /// gelmesi zararsız, arayüz yalnız ürettiği tarihlere bakar); alt sınırı
  /// kaydırmamak ise ızgaranın soldaki günlerini boş gösterirdi.
  Stream<Map<String, Set<String>>> completionsRangeStream(
    String userId,
    int days, {
    DateTime? endDay,
  }) {
    final end = endDay ?? DateTime.now();
    final start = _fmt(end.subtract(Duration(days: days - 1)));
    return _db
        .collection('habit_completions')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start)
        .snapshots()
        .map((s) {
          final result = <String, Set<String>>{};
          for (final doc in s.docs) {
            final date = doc.data()['date'];
            final habitId = _completionHabitId(doc);
            if (date is! String || habitId == null) continue;
            result.putIfAbsent(date, () => {}).add(habitId);
          }
          return result;
        });
  }

  // Toggle: if the doc exists delete it, otherwise create it.
  //
  // Wrapped in a transaction so the read-then-write is atomic — without
  // this, two rapid taps (or the same habit toggled from two devices near-
  // simultaneously) could both read "not completed" before either write
  // lands, leaving the completion state inconsistent with what the user
  // last saw on screen.
  Future<void> toggleCompletion(
    String userId,
    String habitId,
    String date,
  ) async {
    final docId = '${date}_$habitId';
    final ref = _db.collection('habit_completions').doc(docId);

    final created = await _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        tx.delete(ref);
        return false;
      }
      tx.set(ref, {
        'habitId': habitId,
        'userId': userId,
        'date': date,
        'completedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });

    if (created) {
      unawaited(CheckinRepository.markActiveToday(userId));
    }
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
