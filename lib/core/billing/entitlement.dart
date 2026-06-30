import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/billing/revenue_cat_service.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';

// SharedPreferences key — fallback when RevenueCat is not configured
const _kIsPremium = 'is_premium';

/// Whether the current user has an active ILND+ subscription.
///
/// Checks RevenueCat first; falls back to the local SharedPreferences flag
/// when RevenueCat is not initialised (e.g. missing API key in dev).
final isPremiumProvider = StateNotifierProvider<EntitlementNotifier, bool>((
  ref,
) {
  return EntitlementNotifier(ref.watch(sharedPreferencesProvider));
});

class EntitlementNotifier extends StateNotifier<bool> {
  EntitlementNotifier(this._prefs)
    : super(_prefs.getBool(_kIsPremium) ?? false) {
    _syncFromRevenueCat();
  }

  final dynamic _prefs;

  Future<void> _syncFromRevenueCat() async {
    final premium = await RevenueCatService.isPremium();
    if (premium != state) {
      state = premium;
      await _prefs.setBool(_kIsPremium, premium);
    }
  }

  /// Called after a successful purchase or restore.
  Future<void> setPremium(bool value) async {
    state = value;
    await _prefs.setBool(_kIsPremium, value);
  }
}
