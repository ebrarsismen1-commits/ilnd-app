import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kOnboardingDone = 'onboarding_done';
const _kUserName = 'user_name';
const _kOnboardingGoals = 'onboarding_goals';
const _kOnboardingFrequency = 'onboarding_frequency';

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
