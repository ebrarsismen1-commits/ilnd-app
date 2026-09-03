import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/repositories/food_repository.dart';
import 'package:ilnd_app/features/habits/habits_provider.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';

/// Takip ekranının "hangi gün" katmanı.
///
/// Takip ekranı bugüne çakılıydı: dün ne yediğini görmek isteyen kullanıcının
/// hiçbir kapısı yoktu. Geçmişi ayrı bir "geçmiş" ekranına koymak yerine gün
/// gezgini seçildi — aynı ekran, tek eksende geriye gider (owner kararı).
/// Bu yüzden buradaki her provider "bugün"ün değil, SEÇİLİ günün karşılığıdır.
///
/// Bugün seçiliyken hepsi mevcut bugün-provider'larına devreder: aynı sorgu
/// iki ayrı Firestore dinleyicisiyle açılmasın ve Bugün ekranıyla takip ekranı
/// aynı akışı paylaşsın diye.

// ─── Gün yardımcıları ────────────────────────────────────────────────────────

/// Bir günün anahtarı (YYYY-MM-DD) — alışkanlık ve su kayıtları bu biçimde
/// saklanır.
String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Günün gece yarısı. Seçili gün her zaman normalize edilir: aksi halde aynı
/// güne ait iki farklı `DateTime` ayrı birer family anahtarı olur ve aynı gün
/// için iki dinleyici açılır.
DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

// ─── Seçili gün ──────────────────────────────────────────────────────────────

/// Takip ekranının baktığı gün. Varsayılan bugün; ileri gidilmez.
final selectedDayProvider = StateProvider<DateTime>(
  (_) => startOfDay(DateTime.now()),
);

/// Seçili gün bugün mü — geçmiş gün salt okunur olduğu için arayüzün en sık
/// sorduğu soru.
final isTodaySelectedProvider = Provider<bool>(
  (ref) => dayKey(ref.watch(selectedDayProvider)) == dayKey(DateTime.now()),
);

// ─── Öğünler ─────────────────────────────────────────────────────────────────

final foodEntriesForDayProvider =
    StreamProvider.family<List<FoodEntry>, DateTime>((ref, day) {
      final repo = ref.watch(foodRepositoryProvider);
      if (repo == null) return const Stream.empty();
      return repo.streamForDay(day);
    });

/// Seçili günün öğünleri.
final selectedDayEntriesProvider = Provider<AsyncValue<List<FoodEntry>>>((ref) {
  final day = ref.watch(selectedDayProvider);
  return ref.watch(isTodaySelectedProvider)
      ? ref.watch(todayFoodEntriesProvider)
      : ref.watch(foodEntriesForDayProvider(day));
});

/// Seçili günün makro toplamı. Ekranın kahraman sayısı buradan gelir.
final selectedDayMacrosProvider = Provider<DailyMacros>((ref) {
  final entries = ref.watch(selectedDayEntriesProvider).valueOrNull ?? const [];
  return DailyMacros.fromEntries(entries);
});

// ─── Alışkanlık tamamlamaları ────────────────────────────────────────────────

final completionsForDayProvider = StreamProvider.family<Set<String>, DateTime>((
  ref,
  day,
) {
  final userId = ref.watch(habitsUserIdProvider);
  if (userId == null) return const Stream.empty();
  return ref
      .watch(habitsRepositoryProvider)
      .completionsStream(userId, dayKey(day));
});

/// Seçili günde tamamlanmış alışkanlıklar.
final selectedDayCompletionsProvider = Provider<AsyncValue<Set<String>>>((ref) {
  final day = ref.watch(selectedDayProvider);
  return ref.watch(isTodaySelectedProvider)
      ? ref.watch(todayCompletionsProvider)
      : ref.watch(completionsForDayProvider(day));
});

/// Izgara penceresi: kaç günlük (hafta/ay) ve hangi günde bitiyor.
typedef TrackingWindow = ({TrackingRange range, DateTime day});

final windowCompletionsProvider =
    StreamProvider.family<Map<String, Set<String>>, TrackingWindow>((
      ref,
      window,
    ) {
      final userId = ref.watch(habitsUserIdProvider);
      if (userId == null) return const Stream.empty();
      return ref
          .watch(habitsRepositoryProvider)
          .completionsRangeStream(
            userId,
            window.range.days,
            endDay: window.day,
          );
    });

/// Seçili günde biten pencerenin tamamlamaları.
final selectedDayRangeCompletionsProvider =
    Provider<AsyncValue<Map<String, Set<String>>>>((ref) {
      final range = ref.watch(trackingRangeProvider);
      final day = ref.watch(selectedDayProvider);
      return ref.watch(isTodaySelectedProvider)
          ? ref.watch(rangeCompletionsProvider(range))
          : ref.watch(windowCompletionsProvider((range: range, day: day)));
    });

// ─── Su ──────────────────────────────────────────────────────────────────────

/// Seçili günde içilen su (ml). Geçmiş gün diskteki kayıttan okunur; bugün
/// canlı sayaçtan gelir ki bardak eklendiğinde kart anında tazelensin.
final selectedDayWaterProvider = Provider<int>((ref) {
  if (ref.watch(isTodaySelectedProvider)) return ref.watch(waterTodayProvider);
  final day = ref.watch(selectedDayProvider);
  return ref.watch(sharedPreferencesProvider).getInt(waterKey(dayKey(day))) ??
      0;
});

/// Seçili günde biten pencerenin günlük su kayıtları, eskiden yeniye.
final selectedDayWaterHistoryProvider = Provider<List<int>>((ref) {
  final range = ref.watch(trackingRangeProvider);
  if (ref.watch(isTodaySelectedProvider)) {
    return ref.watch(waterHistoryProvider(range));
  }
  final prefs = ref.watch(sharedPreferencesProvider);
  final day = ref.watch(selectedDayProvider);
  return [
    for (var back = range.days - 1; back >= 0; back--)
      prefs.getInt(waterKey(dayKey(day.subtract(Duration(days: back))))) ?? 0,
  ];
});
