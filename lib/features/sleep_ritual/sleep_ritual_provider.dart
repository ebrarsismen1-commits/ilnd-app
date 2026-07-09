import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/sleep_ritual/sleep_ritual_models.dart';

// ─── Akşam penceresi ──────────────────────────────────────────────────────────

/// Ana sayfadaki gece ritüeli daveti yalnız akşam saatlerinde görünür.
/// Saat parametre olarak alınır ki test edilebilsin (_heroImageUrl emsali).
bool isSleepRitualWindow(int hour) => hour >= 21 || hour < 4;

// ─── Bu gece yapıldı bayrağı ──────────────────────────────────────────────────
// todaysMoodProvider deseninin klonu: tarih + değer anahtarı, tarih bugün
// değilse false. Cihaza-yerel günlük bayrak — mood check-in ile aynı yaşam
// döngüsü, o yüzden aynı desen.

const _kSleepRitualDate = 'sleep_ritual_date';
const _kSleepRitualDone = 'sleep_ritual_done';

final sleepRitualDoneTonightProvider =
    StateNotifierProvider<SleepRitualDoneTonightNotifier, bool>((ref) {
      return SleepRitualDoneTonightNotifier(
        ref.watch(sharedPreferencesProvider),
      );
    });

class SleepRitualDoneTonightNotifier extends StateNotifier<bool> {
  SleepRitualDoneTonightNotifier(this._prefs) : super(_readIfToday(_prefs));

  final SharedPreferences _prefs;

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static bool _readIfToday(SharedPreferences prefs) {
    if (prefs.getString(_kSleepRitualDate) != _today()) return false;
    return prefs.getBool(_kSleepRitualDone) ?? false;
  }

  Future<void> record() async {
    state = true;
    await _prefs.setString(_kSleepRitualDate, _today());
    await _prefs.setBool(_kSleepRitualDone, true);
  }
}

// ─── Akış state machine'i ─────────────────────────────────────────────────────

/// autoDispose: ekran kapanınca akış sıfırlanır — yarıda bırakmak hiçbir şey
/// kaydetmez, sonraki açılış temiz seçim ekranından başlar (suçluluk yok).
final sleepRitualFlowProvider =
    StateNotifierProvider.autoDispose<
      SleepRitualFlowNotifier,
      SleepRitualFlowState
    >((ref) => SleepRitualFlowNotifier(ref));

class SleepRitualFlowNotifier extends StateNotifier<SleepRitualFlowState> {
  SleepRitualFlowNotifier(this._ref, {Random? random})
    : _random = random ?? Random(),
      super(const SleepRitualFlowState());

  final Ref _ref;
  final Random _random;

  void toggleStep(SleepRitualStep step) {
    if (step == SleepRitualStep.closing) return; // kapanış hep dahil
    final next = {...state.selected};
    next.contains(step) ? next.remove(step) : next.add(step);
    state = state.copyWith(selected: next);
  }

  void togglePrepItem(int i) {
    final next = {...state.prepChecked};
    next.contains(i) ? next.remove(i) : next.add(i);
    state = state.copyWith(prepChecked: next);
  }

  void setUnloadText(String s) => state = state.copyWith(unloadText: s);

  void setGratitudeText(String s) => state = state.copyWith(gratitudeText: s);

  void start() {
    if (!state.canStart) return;
    final queue = [
      for (final s in kSleepRitualSelectableSteps)
        if (state.selected.contains(s)) s,
      SleepRitualStep.closing,
    ];
    state = state.copyWith(
      phase: SleepRitualPhase.running,
      queue: queue,
      index: 0,
      closingIndex: _random.nextInt(kSleepRitualClosingCount),
    );
  }

  /// Sıradaki adıma geçer; kapanıştan sonra akışı bitirir: bayrak kaydedilir,
  /// yazı girdileri AI hafızasına not düşer.
  Future<void> advance() async {
    if (state.phase != SleepRitualPhase.running) return;
    if (state.index + 1 < state.queue.length) {
      state = state.copyWith(index: state.index + 1);
      return;
    }

    final unload = state.unloadText.trim();
    final gratitude = state.gratitudeText.trim();
    state = state.copyWith(phase: SleepRitualPhase.done);

    await _ref.read(sleepRitualDoneTonightProvider.notifier).record();
    if (!mounted) return;
    // AI-görünür notlar kanonik TR (desen: mood check-in notu, profile_sync).
    final memory = _ref.read(ilndMemoryProvider.notifier);
    if (unload.isNotEmpty) {
      await memory.addNote('Gece ritüelinde yarına bıraktığı not: $unload');
      if (!mounted) return;
    }
    if (gratitude.isNotEmpty) {
      await memory.addNote('Gece ritüelinde günün güzel anı: $gratitude');
      if (!mounted) return;
    }
  }
}
