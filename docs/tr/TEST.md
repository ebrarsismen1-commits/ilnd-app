# Test Kılavuzu

## Test Paketi Genel Bakışı

| Katman | Konum | Sayı | Çalıştırıcı |
|--------|-------|------|------------|
| Birim — doğrulayıcılar | `test/core/validators_test.dart` | 18 | `flutter test` |
| Birim — seri kopyası | `test/core/streak_copy_test.dart` | 7 | `flutter test` |
| Birim — kullanım sayacı | `test/core/usage_meter_test.dart` | 7 | `flutter test` |
| Birim — vibe card kopyası | `test/core/vibe_card_copy_test.dart` | 8 | `flutter test` |
| Widget — giriş ekranı | `test/features/auth/login_screen_test.dart` | 3 | `flutter test` |
| Cloud Function — anthropicProxy | `functions/test/anthropicProxy.test.js` | 5 | `npm test` |
| Cloud Function — redeemReferralCode | `functions/test/redeemReferralCode.test.js` | 6 | `npm test` |
| Cloud Function — deleteAccount | `functions/test/deleteAccount.test.js` | 3 | `npm test` |

**Toplam Flutter testi:** 43  
**Toplam Cloud Function testi:** 14

---

## Flutter Testlerini Çalıştırma

```bash
flutter test                    # tüm testler
flutter test test/core/         # yalnızca birim testler
flutter test --coverage         # kapsam raporu ile
```

---

## Cloud Function Testlerini Çalıştırma

Firebase Emülatörü çalışıyor olmalı:

```bash
# Terminal 1
firebase emulators:start

# Terminal 2
cd functions
npm test
```

App Check zorunlu tutma testleri için:
```bash
export FIREBASE_APP_CHECK_TEST_APP_ID=<test-uygulama-id>
npm test
```

---

## Flutter Test Kalıpları

### Birim testlerinde yerelleştirme

```dart
import 'package:ilnd_app/l10n/app_localizations_tr.dart';

void main() {
  final l10n = AppLocalizationsTr();

  test('e-postayı doğrular', () {
    final dogrulayici = Validators.email(l10n);
    expect(dogrulayici(''), l10n.validatorEmailRequired);
    expect(dogrulayici('gecersiz'), l10n.validatorEmailInvalid);
    expect(dogrulayici('kullanici@ornek.com'), isNull);
  });
}
```

### Supabase ile widget testleri

```dart
setUpAll(() async {
  SharedPreferences.setMockInitialValues({});
  await Supabase.initialize(
    url: 'https://example.supabase.co',
    publishableKey: 'test-anon-key',
  );
});
```

### Animasyonlu widget'ları pompalama

`AnimatedBackground` sonsuz bir `AnimationController` kullanır. Hiçbir zaman `pumpAndSettle()` kullanma:

```dart
// Yanlış — zaman aşımı olur
await tester.pumpAndSettle();

// Doğru
await tester.pump();
await tester.pump(const Duration(milliseconds: 100));
```

### Provider geçersiz kılmaları

```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: const MaterialApp(
      locale: Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: GirisEkrani(),
    ),
  ),
);
```

### RichText / TextSpan içinde metin bulma

```dart
find.textContaining(l10n.registerLoginLink, findRichText: true)
```

---

## CI Entegrasyonu

Her push ve pull request'te GitHub Actions tarafından otomatik olarak çalıştırılır ([`.github/workflows/ci.yml`](../../.github/workflows/ci.yml)):

```yaml
# Flutter işleri
flutter analyze
flutter test --coverage
dart format --set-exit-if-changed lib test

# Cloud Functions işi
cd functions && npm ci && npm run lint && npm test
```

---

## Test Edilmeyen Alanlar

| Boşluk | Neden | Risk |
|--------|-------|------|
| `mintFirebaseToken` | Gerçek Supabase JWKS uç noktası gerektirir | Düşük |
| Emülatörde App Check zorunluluğu | `FIREBASE_APP_CHECK_TEST_APP_ID` CI sırrı gerektirir | Orta |
| RevenueCat satın alma akışı | Sandbox kimlik bilgileri gerektirir | Düşük |
| Tam navigasyon akışı | Karmaşık entegrasyon kurulumu | Düşük — smoke test ile kapsanır |

---

## İlgili Belgeler

- [GELISTIRME.md](GELISTIRME.md) — yeni test yazma
- [MIMARI.md](MIMARI.md) — test bağlamı için sistem genel bakışı
- [API.md](API.md) — Cloud Function istek/yanıt şekilleri
