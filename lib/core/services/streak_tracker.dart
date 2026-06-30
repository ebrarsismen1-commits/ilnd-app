import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ilnd_app/core/services/analytics_service.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';

const _kLongestStreak = 'longest_streak';
const _kLastObservedStreak = 'last_observed_streak';
const _milestones = [7, 30, 100];

/// En uzun seri — SharedPreferences'ta lokal tutulur, ayrı bir Firestore
/// tablosu veya gece çalışan bir job gerekmez. Streak her zaten mevcut
/// journal/habit verisinden anlık hesaplanıyor ([profileStatsProvider]) —
/// bu sadece o değerin tarihçesini (en yüksek nokta) tutar.
final longestStreakProvider = StateNotifierProvider<LongestStreakNotifier, int>(
  (ref) {
    return LongestStreakNotifier(ref.watch(sharedPreferencesProvider));
  },
);

class LongestStreakNotifier extends StateNotifier<int> {
  LongestStreakNotifier(this._prefs)
    : super(_prefs.getInt(_kLongestStreak) ?? 0);

  final SharedPreferences _prefs;

  /// Taze hesaplanmış güncel seriyi bildirir; en uzun seriyi günceller ve
  /// uzama/kırılma/milestone event'lerini bir önceki gözlemle kıyaslayarak
  /// tetikler. Utandırıcı değil — kırılma sadece nazik bir "yeniden başla"
  /// metni için kullanılır, ceza/uyarı yok.
  Future<void> observe(int streakDays) async {
    final lastObserved = _prefs.getInt(_kLastObservedStreak) ?? 0;

    if (streakDays > state) {
      state = streakDays;
      await _prefs.setInt(_kLongestStreak, streakDays);
    }

    if (streakDays > lastObserved && streakDays > 0) {
      unawaited(
        AnalyticsService.logEvent('streak_extended', {'days': streakDays}),
      );
    } else if (streakDays == 0 && lastObserved > 0) {
      unawaited(
        AnalyticsService.logEvent('streak_broken', {
          'previous_days': lastObserved,
        }),
      );
    }

    for (final milestone in _milestones) {
      if (streakDays >= milestone && lastObserved < milestone) {
        unawaited(
          AnalyticsService.logEvent('streak_milestone_reached', {
            'milestone': milestone,
          }),
        );
      }
    }

    if (streakDays != lastObserved) {
      await _prefs.setInt(_kLastObservedStreak, streakDays);
    }
  }
}
