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
      .map((s) => s.docs.map((d) => d['habitId'] as String).toSet());

  // Returns completions for the last 7 days: { 'YYYY-MM-DD': { habitId, ... } }
  Stream<Map<String, Set<String>>> last7DaysStream(String userId) {
    final now = DateTime.now();
    final dates = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return _fmt(d);
    });
    return _db
        .collection('habit_completions')
        .where('userId', isEqualTo: userId)
        .where('date', whereIn: dates)
        .snapshots()
        .map((s) {
          final result = <String, Set<String>>{};
          for (final doc in s.docs) {
            final date = doc['date'] as String;
            final habitId = doc['habitId'] as String;
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
