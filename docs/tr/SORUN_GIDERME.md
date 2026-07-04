# Sorun Giderme Kılavuzu

## Flutter / Dart

### `flutter pub get` başarısız olursa

```bash
flutter clean
rm -rf .dart_tool/ .flutter-plugins .flutter-plugins-dependencies
flutter pub get
```

### `flutter analyze` birleştirmeden sonra hata bildirirse

Önce yerelleştirmeleri yeniden oluştur — oluşturulan dosyalar senkronize olmayabilir:
```bash
flutter gen-l10n
flutter analyze
```

### Uygulama başlangıçta `_StartupFailureApp` gösteriyor

Supabase başlatması başarısız oldu. Kontrol et:
1. `.env` dosyasındaki `SUPABASE_URL` — Supabase proje URL'inle tam eşleşmeli
2. `SUPABASE_ANON_KEY` — hizmet rolü anahtarı değil, genel anon anahtarı olmalı
3. Emülatörde/cihazda ağ bağlantısı

### Sıcak yeniden yükleme çalışıyor ama değişiklikler görünmüyor

Bazı değişiklikler sıcak **yeniden başlatma** gerektirir (terminalde `R` veya IDE yeniden başlatma):
- Provider tanımları değişti
- Router yapılandırması değişti
- `.arb` dosyası değişiklikleri (`flutter gen-l10n` de gerektirir)

### Widget testlerinde `pumpAndSettle()` zaman aşımı

`AnimatedBackground` sonsuz animasyon çalıştırır. Şunu kullan:
```dart
await tester.pump();
await tester.pump(const Duration(milliseconds: 100));
```

### Widget testi yanlış yerel ayar gösteriyor

Test `MaterialApp`'inde yerel ayarı açıkça belirt:
```dart
child: const MaterialApp(
  locale: Locale('tr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BenimEkranim(),
),
```

---

## Firebase / Firestore

### Firebase emülatörü başlatılamıyor

Gerekli portların boş olduğunu kontrol et:
```bash
lsof -i :4000 -i :5001 -i :8080 -i :9099 -i :9199
kill -9 <PID>
```

### Emülatör başlıyor ama uygulama hâlâ üretim Firebase'i çağırıyor

Flutter uygulaması, yalnızca `kDebugMode == true` olduğunda emülatörlere bağlanır. Profil veya yayın derlemesi çalıştırıyorsan, üretimi kullanır.

Her zaman `flutter run` ile test et (debug modu).

### Firestore yazmaları sessizce başarısız oluyor

Büyük olasılıkla güvenlik kuralı reddi. [http://localhost:4000](http://localhost:4000) adresindeki Emülatör Arayüzü → Firestore → İstekler sekmesinde izin reddini kontrol et.

Yaygın neden: kuralların koruduğu bir alana yazma girişimi (örn. `user_growth`'taki `founding_member`).

### `habit_completions` sorgusu "dizin gerekli" hatası veriyor

Bileşik dizin dağıtılmalı:
```bash
firebase deploy --only firestore:indexes
```

### Cloud Function 401 döndürüyor

- `Authorization` başlığında eksik veya süresi dolmuş Firebase ID token
- Zorunlu tutulan fonksiyonlar için `X-Firebase-AppCheck` başlığında eksik App Check token
- Testlerde: emülatörün çalıştığını ve `FIREBASE_APP_CHECK_TEST_APP_ID`'nin ayarlı olduğunu kontrol et

### Cloud Function 429 döndürüyor

Kullanıcı günlük AI kullanım kotasına ulaştı:
- `quick` katman: 300 istek/gün
- `deep` katman: 60 istek/gün

Sayaç gece yarısı UTC'de sıfırlanır. Geliştirme sırasında sıfırlamak için Emülatör Arayüzü'nde `ai_usage/{uid}/` belgelerini sil.

---

## Kimlik Doğrulama

### Giriş çalışıyor ama Firestore okumaları başarısız oluyor

Firebase köprüsü tamamlanmamış olabilir. Supabase girişinden sonra, Firebase Auth'a köprülemek için `mintFirebaseToken` çağrılır. Bu sessizce başarısız olursa, Firestore kuralları `request.auth` görmez.

[`lib/features/auth/auth_provider.dart`](../../lib/features/auth/auth_provider.dart) dosyasındaki `_bridgeToFirebase()` metodunu kontrol et.

### `AUTH_BRIDGE_URL` ayarlanmamış — AI sohbet hata gösteriyor

Cloud Functions dağıtıldıktan sonra `.env` dosyasındaki `AUTH_BRIDGE_URL`'yi güncelle:
```ini
AUTH_BRIDGE_URL=https://<bölge>-ilnd-app-8dcbd.cloudfunctions.net/mintFirebaseToken
```

---

## RevenueCat / Premium

### Satın alma akışı tamamlanıyor ama `isPremiumProvider` false kalıyor

RevenueCat hak senkronizasyonu asenkroniktir. Zorla senkronize et veya uygulamayı yeniden başlat.

### Paywall görünüyor ama satın almalar devre dışı

iOS Simülatörde StoreKit testi etkinleştirilmiş olmalı. Tam satın alma testi için fiziksel cihaz kullan.

---

## CI/CD

### CI `dart format` üzerinde başarısız oluyor

Yerel olarak çalıştır ve biçimlendirilmiş çıktıyı commit'le:
```bash
dart format lib test
git add -u
git commit --amend --no-edit
```

### Yayın iş akışı başarısız oluyor — "keystore sırları yapılandırılmamış"

GitHub Actions sırları ayarlanmamış. Bkz. [`android/KEYSTORE.md`](../../android/KEYSTORE.md).

---

## İlgili Belgeler

- [KURULUM.md](KURULUM.md) — ilk kurulum
- [GELISTIRME.md](GELISTIRME.md) — günlük iş akışı
- [FIREBASE.md](FIREBASE.md) — Firestore ve emülatör yapılandırması
- [SSS.md](SSS.md) — sık sorulan sorular
