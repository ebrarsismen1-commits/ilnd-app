import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/services/firebase_service.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class FoodEntry {
  const FoodEntry({
    required this.id,
    required this.yemekAdi,
    required this.kalori,
    required this.protein,
    required this.karbonhidrat,
    required this.yag,
    required this.createdAt,
  });

  final String id;
  final String yemekAdi;
  final int kalori;
  final int protein;
  final int karbonhidrat;
  final int yag;
  final DateTime createdAt;

  factory FoodEntry.fromDoc(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return FoodEntry(
      id: doc.id,
      yemekAdi: d['yemekAdi'] as String? ?? '',
      kalori: (d['kalori'] as num?)?.toInt() ?? 0,
      protein: (d['protein'] as num?)?.toInt() ?? 0,
      karbonhidrat: (d['karbonhidrat'] as num?)?.toInt() ?? 0,
      yag: (d['yag'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap(String userId) => {
        'userId': userId,
        'yemekAdi': yemekAdi,
        'kalori': kalori,
        'protein': protein,
        'karbonhidrat': karbonhidrat,
        'yag': yag,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

// ─── Makro toplamı (bugün) ────────────────────────────────────────────────────

class DailyMacros {
  const DailyMacros({
    required this.kalori,
    required this.protein,
    required this.karbonhidrat,
    required this.yag,
  });
  final int kalori;
  final int protein;
  final int karbonhidrat;
  final int yag;

  static DailyMacros fromEntries(List<FoodEntry> entries) => DailyMacros(
        kalori: entries.fold(0, (s, e) => s + e.kalori),
        protein: entries.fold(0, (s, e) => s + e.protein),
        karbonhidrat: entries.fold(0, (s, e) => s + e.karbonhidrat),
        yag: entries.fold(0, (s, e) => s + e.yag),
      );
}

// ─── Repository ───────────────────────────────────────────────────────────────

class FoodRepository {
  FoodRepository(this._userId);

  final String _userId;

  CollectionReference<Map<String, dynamic>> get _col => FirebaseService.firestore
      .collection('users')
      .doc(_userId)
      .collection('food_entries');

  Stream<List<FoodEntry>> streamToday() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return _col
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(FoodEntry.fromDoc).toList());
  }

  Future<void> add(FoodEntry entry) => _col.add(entry.toMap(_userId));
}

// ─── Providers ────────────────────────────────────────────────────────────────

final foodRepositoryProvider = Provider<FoodRepository?>((ref) {
  final auth = ref.watch(authNotifierProvider);
  if (auth is AuthAuthenticated) return FoodRepository(auth.user.id);
  return null;
});

final todayFoodEntriesProvider = StreamProvider<List<FoodEntry>>((ref) {
  final repo = ref.watch(foodRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.streamToday();
});

final dailyMacrosProvider = Provider<DailyMacros>((ref) {
  final entries = ref.watch(todayFoodEntriesProvider).valueOrNull ?? [];
  return DailyMacros.fromEntries(entries);
});
