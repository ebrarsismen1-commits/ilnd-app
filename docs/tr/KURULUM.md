# Kurulum Kılavuzu

## Ön Koşullar

| Araç | Gerekli Sürüm | Kurulum |
|------|--------------|---------|
| Flutter | 3.44.1 | [flutter.dev/install](https://flutter.dev/install) |
| Dart | 3.12.1 (Flutter ile birlikte gelir) | — |
| Node.js | 20.x | [nodejs.org](https://nodejs.org) |
| Firebase CLI | En güncel | `npm install -g firebase-tools` |
| Xcode | 15+ | Mac App Store (iOS derleme için) |
| Android Studio | En güncel | Android emülatör için |
| Git | Herhangi | — |

Flutter kurulumunu doğrula:
```bash
flutter doctor -v
```

Hedef platform için tüm işaretler yeşil olmalıdır. iOS derlemesi Mac gerektirir.

---

## 1. Depoyu Klonla

```bash
git clone <repo-url> ilnd_app
cd ilnd_app
```

---

## 2. Ortam Yapılandırması

Uygulama, proje kökündeki `.env` dosyasından gizli anahtarları okur:

```bash
cp .env.example .env
```

`.env` dosyasını düzenle:
```ini
# Supabase
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Firebase (google-services.json / GoogleService-Info.plist'ten)
FIREBASE_API_KEY=AIzaSy...
FIREBASE_AUTH_DOMAIN=ilnd-app-8dcbd.firebaseapp.com
FIREBASE_PROJECT_ID=ilnd-app-8dcbd
FIREBASE_STORAGE_BUCKET=ilnd-app-8dcbd.appspot.com
FIREBASE_MESSAGING_SENDER_ID=...
FIREBASE_APP_ID=...

# RevenueCat
REVENUECAT_API_KEY=appl_...

# Cloud Functions köprü URL'i (fonksiyonlar dağıtıldıktan sonra güncelle)
AUTH_BRIDGE_URL=https://<bölge>-ilnd-app-8dcbd.cloudfunctions.net/mintFirebaseToken
```

> **Not:** `ANTHROPIC_API_KEY` bir Firebase Secret'tır — `.env` dosyasına ekleme. Cloud Function gizli anahtarlarının nasıl ayarlanacağı için [DAGITIM.md](DAGITIM.md) belgesine bak.

---

## 3. Firebase Yapılandırma Dosyaları

Firebase Console → Proje Ayarları bölümünden indir:

- **Android:** `google-services.json` → `android/app/google-services.json` konumuna yerleştir
- **iOS:** `GoogleService-Info.plist` → `ios/Runner/GoogleService-Info.plist` konumuna yerleştir

Her iki dosya da `.gitignore` kapsamındadır; Firebase Console'dan veya takım üyesinden temin edilmelidir.

---

## 4. Flutter Bağımlılıkları

```bash
flutter pub get
```

---

## 5. Cloud Functions Kurulumu

```bash
cd functions
npm install
cd ..
```

---

## 6. Firebase Emülatör Paketi (yerel geliştirme için)

Emülatör, geliştirme sırasında tüm Firebase servislerinin yerini alır. Gerçek Firestore veya Auth çağrısı yapılmaz.

```bash
firebase login          # ilk kez
firebase use ilnd-app-8dcbd
firebase emulators:start
```

Emülatör portları:
| Servis | Port |
|--------|------|
| Firebase Auth | 9099 |
| Firestore | 8080 |
| Cloud Functions | 5001 |
| Storage | 9199 |
| Emülatör Arayüzü | 4000 |

[http://localhost:4000](http://localhost:4000) adresini açarak emülatör durumunu inceleyebilirsin.

---

## 7. Makale İçeriği Yükle

Emülatör çalışırken (veya üretim ortamında uygun kimlik bilgileriyle):

```bash
cd functions
npm run seed:articles
```

Bu komut [`content/articles.json`](../../content/articles.json) dosyasını okuyarak 10 makaleyi Firestore'a yükler. Script idempotenttir — birden fazla kez çalıştırmak güvenlidir.

---

## 8. Uygulamayı Çalıştır

### iOS Simülatör

```bash
open -a Simulator
flutter run
```

### Android Emülatör

Android Studio'dan bir AVD başlat, ardından:

```bash
flutter run
```

### Fiziksel Cihaz

```bash
flutter devices             # bağlı cihazları listele
flutter run -d <cihaz-id>
```

---

## 9. Kurulumu Doğrula

Uygulama başladıktan sonra:

1. Yeni hesap oluştur — Supabase kullanıcı oluşturur, `mintFirebaseToken` Firebase'e köprüler
2. Katılımı tamamla (karşılama → hızlı kurulum → ilk günlük girişi)
3. İlk giriş, `anthropicProxy` üzerinden ILND yapay zeka yanıtını tetikler
4. Ana ekran ruh hali kontrolü ve günün makalesini gösterir

AI yanıtı uçtan uca çalışıyorsa kurulum tamamlanmıştır.

---

## Sorun Giderme

**`flutter pub get` bağımlılık çakışmasıyla başarısız olursa:**
```bash
flutter clean && flutter pub get
```

**`firebase emulators:start` askıda kalırsa:**
4000, 5001, 8080, 9099, 9199 portlarının boş olduğunu kontrol et:
```bash
lsof -i :8080
```

**Uygulama `_StartupFailureApp` gösteriyorsa:**
`.env` dosyasındaki Supabase URL veya anon key hatalı. Değerlerin Supabase projenle eşleştiğini kontrol et.

**Makaleler yüklenmiyorsa:**
`functions/` dizininden `npm run seed:articles` komutunu çalıştır. Emülatör kullanıyorsan, seed çalıştırmadan önce emülatörün aktif olması gerekir.

---

## İlgili Belgeler

- [GELISTIRME.md](GELISTIRME.md) — günlük iş akışı
- [DAGITIM.md](DAGITIM.md) — üretim dağıtımı
- [FIREBASE.md](FIREBASE.md) — Firestore ve emülatör yapılandırması
