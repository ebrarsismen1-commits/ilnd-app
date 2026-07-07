import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kOnboardingDone = 'onboarding_done';
const _kUserName = 'user_name';
const _kOnboardingGoals = 'onboarding_goals';
const _kOnboardingFrequency = 'onboarding_frequency';
const _kFirstEntryDone = 'first_entry_done';
const _kPendingReferralCode = 'pending_referral_code';
const _kOnboardingAge = 'onboarding_age';
const _kOnboardingHeight = 'onboarding_height';
const _kOnboardingWeight = 'onboarding_weight';
const _kOnboardingDiet = 'onboarding_diet';
const _kOnboardingAllergies = 'onboarding_allergies';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override this provider with the real instance');
});

// ── Onboarding tamamlandı mı? (reaktif StateNotifier) ─────────────────────────

final onboardingDoneProvider =
    StateNotifierProvider<OnboardingDoneNotifier, bool>((ref) {
      return OnboardingDoneNotifier(ref.watch(sharedPreferencesProvider));
    });

class OnboardingDoneNotifier extends StateNotifier<bool> {
  OnboardingDoneNotifier(this._prefs)
    : super(_prefs.getBool(_kOnboardingDone) ?? false);

  final SharedPreferences _prefs;

  Future<void> setDone() async {
    await _prefs.setBool(_kOnboardingDone, true);
    state = true; // router'ı anında tetikler
  }
}

// ── Kullanıcı adı ─────────────────────────────────────────────────────────────

final userNameProvider = StateNotifierProvider<UserNameNotifier, String>((ref) {
  return UserNameNotifier(ref.watch(sharedPreferencesProvider));
});

class UserNameNotifier extends StateNotifier<String> {
  UserNameNotifier(this._prefs) : super(_prefs.getString(_kUserName) ?? '');

  final SharedPreferences _prefs;

  Future<void> save(String name) async {
    state = name;
    await _prefs.setString(_kUserName, name);
  }
}

// ── Onboarding cevapları ──────────────────────────────────────────────────────

final onboardingGoalsProvider =
    StateNotifierProvider<OnboardingGoalsNotifier, List<String>>((ref) {
      return OnboardingGoalsNotifier(ref.watch(sharedPreferencesProvider));
    });

class OnboardingGoalsNotifier extends StateNotifier<List<String>> {
  OnboardingGoalsNotifier(this._prefs)
    : super(_prefs.getStringList(_kOnboardingGoals) ?? []);

  final SharedPreferences _prefs;

  Future<void> toggle(String goal) async {
    final updated = state.contains(goal)
        ? state.where((g) => g != goal).toList()
        : [...state, goal];
    state = updated;
    await _prefs.setStringList(_kOnboardingGoals, updated);
  }

  /// Sunucudan hidratlama için tüm listeyi bir kerede yazar (ADR-0003).
  Future<void> setAll(List<String> goals) async {
    state = List<String>.from(goals);
    await _prefs.setStringList(_kOnboardingGoals, state);
  }
}

final onboardingFrequencyProvider =
    StateNotifierProvider<OnboardingFrequencyNotifier, String?>((ref) {
      return OnboardingFrequencyNotifier(ref.watch(sharedPreferencesProvider));
    });

class OnboardingFrequencyNotifier extends StateNotifier<String?> {
  OnboardingFrequencyNotifier(this._prefs)
    : super(_prefs.getString(_kOnboardingFrequency));

  final SharedPreferences _prefs;

  Future<void> select(String value) async {
    state = value;
    await _prefs.setString(_kOnboardingFrequency, value);
  }
}

// ── Yaş / boy / kilo (nullable — kullanıcı boş bırakabilir) ───────────────────

final onboardingAgeProvider = StateNotifierProvider<_NullableIntNotifier, int?>(
  (ref) {
    return _NullableIntNotifier(
      ref.watch(sharedPreferencesProvider),
      _kOnboardingAge,
    );
  },
);

final onboardingHeightProvider =
    StateNotifierProvider<_NullableIntNotifier, int?>((ref) {
      return _NullableIntNotifier(
        ref.watch(sharedPreferencesProvider),
        _kOnboardingHeight,
      );
    });

final onboardingWeightProvider =
    StateNotifierProvider<_NullableIntNotifier, int?>((ref) {
      return _NullableIntNotifier(
        ref.watch(sharedPreferencesProvider),
        _kOnboardingWeight,
      );
    });

class _NullableIntNotifier extends StateNotifier<int?> {
  _NullableIntNotifier(this._prefs, this._key) : super(_prefs.getInt(_key));

  final SharedPreferences _prefs;
  final String _key;

  Future<void> save(int? value) async {
    state = value;
    if (value == null) {
      await _prefs.remove(_key);
    } else {
      await _prefs.setInt(_key, value);
    }
  }
}

// ── Beslenme tercihi (tekil seçim) ─────────────────────────────────────────────

final onboardingDietProvider =
    StateNotifierProvider<OnboardingDietNotifier, String?>((ref) {
      return OnboardingDietNotifier(ref.watch(sharedPreferencesProvider));
    });

class OnboardingDietNotifier extends StateNotifier<String?> {
  OnboardingDietNotifier(this._prefs)
    : super(_prefs.getString(_kOnboardingDiet));

  final SharedPreferences _prefs;

  Future<void> select(String? value) async {
    state = value;
    if (value == null) {
      await _prefs.remove(_kOnboardingDiet);
    } else {
      await _prefs.setString(_kOnboardingDiet, value);
    }
  }
}

// ── Alerjiler (çoklu seçim) ─────────────────────────────────────────────────────

final onboardingAllergiesProvider =
    StateNotifierProvider<OnboardingAllergiesNotifier, List<String>>((ref) {
      return OnboardingAllergiesNotifier(ref.watch(sharedPreferencesProvider));
    });

class OnboardingAllergiesNotifier extends StateNotifier<List<String>> {
  OnboardingAllergiesNotifier(this._prefs)
    : super(_prefs.getStringList(_kOnboardingAllergies) ?? []);

  final SharedPreferences _prefs;

  Future<void> toggle(String allergy) async {
    final updated = state.contains(allergy)
        ? state.where((a) => a != allergy).toList()
        : [...state, allergy];
    state = updated;
    await _prefs.setStringList(_kOnboardingAllergies, updated);
  }

  /// Sunucudan hidratlama için tüm listeyi bir kerede yazar (ADR-0003).
  Future<void> setAll(List<String> allergies) async {
    state = List<String>.from(allergies);
    await _prefs.setStringList(_kOnboardingAllergies, state);
  }
}

// ── İlk günlük kaydı tamamlandı mı? (auth sonrası, onboarding'in son adımı) ───

final firstEntryDoneProvider =
    StateNotifierProvider<FirstEntryDoneNotifier, bool>((ref) {
      return FirstEntryDoneNotifier(ref.watch(sharedPreferencesProvider));
    });

class FirstEntryDoneNotifier extends StateNotifier<bool> {
  FirstEntryDoneNotifier(this._prefs)
    : super(_prefs.getBool(_kFirstEntryDone) ?? false);

  final SharedPreferences _prefs;

  Future<void> setDone() async {
    await _prefs.setBool(_kFirstEntryDone, true);
    state = true; // router'ı anında tetikler
  }
}

// ── Auth öncesi girilen davet kodu (auth sonrası redeem edilmek üzere) ────────

final referralCodeInputProvider =
    StateNotifierProvider<ReferralCodeInputNotifier, String?>((ref) {
      return ReferralCodeInputNotifier(ref.watch(sharedPreferencesProvider));
    });

class ReferralCodeInputNotifier extends StateNotifier<String?> {
  ReferralCodeInputNotifier(this._prefs)
    : super(_prefs.getString(_kPendingReferralCode));

  final SharedPreferences _prefs;

  Future<void> save(String code) async {
    final trimmed = code.trim();
    state = trimmed.isEmpty ? null : trimmed;
    if (trimmed.isEmpty) {
      await _prefs.remove(_kPendingReferralCode);
    } else {
      await _prefs.setString(_kPendingReferralCode, trimmed);
    }
  }

  Future<void> clear() async {
    state = null;
    await _prefs.remove(_kPendingReferralCode);
  }
}

// ── Günlük ruh hali check-in'i (Home ekranı) ──────────────────────────────────

const _kMoodCheckInDate = 'mood_checkin_date';
const _kMoodCheckInValue = 'mood_checkin_value';

/// Bugün zaten cevaplandıysa seçilen mood key'ini, cevaplanmadıysa null döner.
/// Tarih karşılaştırması yerel cihaz saatine göre (yyyy-MM-dd).
final todaysMoodProvider = StateNotifierProvider<TodaysMoodNotifier, String?>((
  ref,
) {
  return TodaysMoodNotifier(ref.watch(sharedPreferencesProvider));
});

class TodaysMoodNotifier extends StateNotifier<String?> {
  TodaysMoodNotifier(this._prefs) : super(_readIfToday(_prefs));

  final SharedPreferences _prefs;

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String? _readIfToday(SharedPreferences prefs) {
    final savedDate = prefs.getString(_kMoodCheckInDate);
    if (savedDate != _today()) return null;
    return prefs.getString(_kMoodCheckInValue);
  }

  Future<void> record(String moodKey) async {
    state = moodKey;
    await _prefs.setString(_kMoodCheckInDate, _today());
    await _prefs.setString(_kMoodCheckInValue, moodKey);
  }
}

// ── Şu anki onboarding adımı (terk edilme analytics'i için) ───────────────────

/// (adım indexi, adım adı) — onboarding ekranları initState'te set eder,
/// onboarding tamamen bitince null'a döner. Uygulama arka plana alındığında
/// bu provider null değilse "onboarding_abandoned_at_step" loglanır.
final currentOnboardingStepProvider = StateProvider<(int, String)?>(
  (ref) => null,
);
