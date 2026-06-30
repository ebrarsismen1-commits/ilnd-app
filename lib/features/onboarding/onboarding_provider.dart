import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kOnboardingDone = 'onboarding_done';
const _kUserName = 'user_name';
const _kOnboardingGoals = 'onboarding_goals';
const _kOnboardingFrequency = 'onboarding_frequency';
const _kFirstEntryDone = 'first_entry_done';
const _kPendingReferralCode = 'pending_referral_code';

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

// ── Şu anki onboarding adımı (terk edilme analytics'i için) ───────────────────

/// (adım indexi, adım adı) — onboarding ekranları initState'te set eder,
/// onboarding tamamen bitince null'a döner. Uygulama arka plana alındığında
/// bu provider null değilse "onboarding_abandoned_at_step" loglanır.
final currentOnboardingStepProvider = StateProvider<(int, String)?>(
  (ref) => null,
);
