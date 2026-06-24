import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';

/// Kullanıcının ILND+ (premium) sahibi olup olmadığı.
///
/// Şimdilik lokal bir bayrak; ileride RevenueCat / App Store / Play Billing'e
/// bağlanacak. Tüm limit kontrolleri bu duruma bakar.
const _kIsPremium = 'is_premium';

final isPremiumProvider =
    StateNotifierProvider<EntitlementNotifier, bool>((ref) {
  return EntitlementNotifier(ref.watch(sharedPreferencesProvider));
});

class EntitlementNotifier extends StateNotifier<bool> {
  EntitlementNotifier(this._prefs) : super(_prefs.getBool(_kIsPremium) ?? false);

  final dynamic _prefs; // SharedPreferences

  /// Satın alma/geri yükleme sonrası çağrılır.
  Future<void> setPremium(bool value) async {
    state = value;
    await _prefs.setBool(_kIsPremium, value);
  }
}
