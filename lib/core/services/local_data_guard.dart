import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/billing/entitlement.dart';
import 'package:ilnd_app/core/services/local_user_data.dart';
import 'package:ilnd_app/core/services/streak_tracker.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/features/habits/habits_provider.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/sleep_ritual/sleep_ritual_provider.dart';

/// Kişisel yerel veriyi SharedPreferences'tan kurulurken okuyan sağlayıcılar.
/// Veri silindikten sonra bellekteki eski değeri taşımasınlar diye yeniden
/// kurulurlar. AI hafızası ve sohbet zaten uid değişince yeniden kuruluyor.
void resetPersonalProviders(Ref ref) {
  ref
    ..invalidate(onboardingDoneProvider)
    ..invalidate(userNameProvider)
    ..invalidate(quickSetupStepProvider)
    ..invalidate(onboardingGoalsProvider)
    ..invalidate(onboardingFrequencyProvider)
    ..invalidate(onboardingAgeProvider)
    ..invalidate(onboardingHeightProvider)
    ..invalidate(onboardingWeightProvider)
    ..invalidate(onboardingDietProvider)
    ..invalidate(onboardingAllergiesProvider)
    ..invalidate(firstEntryDoneProvider)
    ..invalidate(referralCodeInputProvider)
    ..invalidate(todaysMoodProvider)
    ..invalidate(sleepRitualDoneTonightProvider)
    ..invalidate(waterTodayProvider)
    ..invalidate(longestStreakProvider)
    ..invalidate(isPremiumProvider);
}

String? _uidOf(AuthState s) => switch (s) {
  AuthAuthenticated(:final user) => user.id,
  AuthPasswordRecovery(:final user) => user.id,
  _ => null,
};

bool _isTransient(AuthState s) =>
    s is AuthInitial || s is AuthLoading || s is AuthError;

/// Çıkışta ve hesap değişiminde önceki kişinin yerel verisini siler
/// (güvenlik denetimi H-2). Uygulama kökünde izlenir (main.dart).
final localDataGuardProvider = Provider<void>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final guard = LocalDataGuard();

  void wipe() {
    unawaited(clearPersonalLocalData(prefs));
    resetPersonalProviders(ref);
  }

  final initial = ref.read(authNotifierProvider);
  if (initial is AuthUnauthenticated &&
      isLegacyOrphanedProfile(prefs, hasSession: false)) {
    unawaited(clearPersonalLocalData(prefs));
    // Bir sağlayıcının kurulumu sırasında başka sağlayıcı geçersiz
    // kılınamaz; bir sonraki mikro görevde.
    scheduleMicrotask(() => resetPersonalProviders(ref));
  }
  guard.observe(uid: _uidOf(initial), transient: _isTransient(initial));

  ref.listen<AuthState>(authNotifierProvider, (_, next) {
    final action = guard.observe(
      uid: _uidOf(next),
      transient: _isTransient(next),
    );
    if (action == LocalDataAction.wipe) wipe();
  });
});
