import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/billing/entitlement.dart';
import 'package:ilnd_app/core/repositories/referral_repository.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Premium erişiminin TEK karar noktası. Kilitli içerik de kullanım kapısı da
/// buraya bakar, ikinci bir kontrol yazılmaz — o yüzden buradaki bir hata ya
/// ödeme yapan kullanıcıyı duvara toslatır ya da herkese premium açar.
///
/// İki kaynak bilerek OR'lanır: cihazdaki mağaza hakkı VEYA hesaba bağlı ödül
/// premium'u. İkincisi şart, çünkü mağaza hakkı cihaz-yereldir — daveti
/// ödüllenmiş kullanıcı ikinci cihazında kilitli içerik görürdü.
UserGrowthProfile _growth({DateTime? until}) => UserGrowthProfile(
  referralCode: 'ABC12345',
  foundingMember: false,
  premiumAccessUntil: until,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// [storePremium] mağaza hakkını doğrudan notifier üzerinden kurar.
  /// SharedPreferences'a tohumlamak yetmez: EntitlementNotifier açılışta
  /// RevenueCat'ten senkronlanıyor ve test ortamında oradan `false` dönüyor —
  /// yani tohumlanan değer yarışı kaybederdi.
  Future<ProviderContainer> container({
    required bool storePremium,
    UserGrowthProfile? growth,
    bool growthLoading = false,
  }) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        myGrowthProfileProvider.overrideWith((ref) async {
          if (growthLoading) return Completer<UserGrowthProfile?>().future;
          return growth;
        }),
      ],
    );
    addTearDown(c.dispose);

    if (storePremium) {
      await c.read(isPremiumProvider.notifier).setPremium(true);
    }
    return c;
  }

  Future<void> settleGrowth(ProviderContainer c, {bool loading = false}) async {
    if (loading) {
      c.read(myGrowthProfileProvider); // dinlemeyi başlat, çözülmesini bekleme
      return;
    }
    await c.read(myGrowthProfileProvider.future);
  }

  group('hasPremiumAccessProvider', () {
    test('mağaza hakkı varsa premiumdur', () async {
      final c = await container(storePremium: true, growth: _growth());
      await settleGrowth(c);
      expect(c.read(hasPremiumAccessProvider), isTrue);
    });

    test('ödül süresi ileri bir tarihse premiumdur', () async {
      final c = await container(
        storePremium: false,
        growth: _growth(until: DateTime.now().add(const Duration(days: 3))),
      );
      await settleGrowth(c);
      expect(
        c.read(hasPremiumAccessProvider),
        isTrue,
        reason: 'Referral ödülü ikinci cihazda da geçerli olmalı',
      );
    });

    test('ödül süresi dolmuşsa premium DEĞİLDİR', () async {
      final c = await container(
        storePremium: false,
        growth: _growth(
          until: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );
      await settleGrowth(c);
      expect(c.read(hasPremiumAccessProvider), isFalse);
    });

    test('hiçbir kaynak yoksa premium değildir', () async {
      final c = await container(storePremium: false, growth: _growth());
      await settleGrowth(c);
      expect(c.read(hasPremiumAccessProvider), isFalse);
    });

    test('growth profili henüz gelmemişken premium AÇILMAZ', () async {
      // Yükleniyor durumunda varsayılan "premium" olsaydı, uygulama her
      // açılışta kısa bir süre herkese premium verirdi.
      final c = await container(storePremium: false, growthLoading: true);
      await settleGrowth(c, loading: true);
      expect(c.read(hasPremiumAccessProvider), isFalse);
    });

    test('growth profili null olsa da çökmez', () async {
      final c = await container(storePremium: false, growth: null);
      await settleGrowth(c);
      expect(c.read(hasPremiumAccessProvider), isFalse);
    });
  });
}
