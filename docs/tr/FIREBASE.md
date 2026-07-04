# Firebase Kılavuzu

## Proje

- **Proje Kimliği:** `ilnd-app-8dcbd`
- **Proje yapılandırması:** [`.firebaserc`](../../.firebaserc), [`firebase.json`](../../firebase.json)
- **Kullanılan servisler:** Auth, Firestore, Cloud Functions, Storage, App Check, Crashlytics, Analytics

---

## Firestore Koleksiyonları

### `users/{uid}`

Kayıt sırasında oluşturulan üst düzey kullanıcı belgesi.

| Alan | Tür | Açıklama |
|------|-----|---------|
| `onboarding_complete` | bool | İlk giriş ekranından sonra `true` |
| `display_name` | string | Hızlı kurulumdan kullanıcı adı |

### `users/{uid}/journal_entries/{entryId}`

| Alan | Tür | Açıklama |
|------|-----|---------|
| `text` | string | Kullanıcının günlük metni |
| `aiResponse` | string | ILND AI yanıtı |
| `mood` | string | Seçilen ruh hali emoji/etiketi |
| `createdAt` | timestamp | Sunucu zaman damgası |

### `habits/{habitId}`

Çapraz kullanıcı sorgulama için üst düzey koleksiyon. Sahiplik Firestore kurallarıyla uygulanır.

| Alan | Tür | Açıklama |
|------|-----|---------|
| `userId` | string | Sahip UID |
| `name` | string | Alışkanlık adı |
| `createdAt` | timestamp | Sunucu zaman damgası |

### `habit_completions/{completionId}`

| Alan | Tür | Açıklama |
|------|-----|---------|
| `userId` | string | Sahip UID |
| `habitId` | string | `habits/{habitId}` referansı |
| `date` | string | ISO tarihi `YYYY-MM-DD` |

**Not:** `toggleCompletion` bir Firestore transaction'ına sarılmıştır — çift dokunma yarış koşulunu ortadan kaldırır.

### `user_growth/{uid}`

Davet ve premium durumu. **İstemci yalnızca oluşturabilir** (kısıtlı alanlar). Güncellemeler yalnızca Admin SDK ile yapılabilir.

| Alan | Tür | Açıklama |
|------|-----|---------|
| `referral_code` | string | Kullanıcının davet kodu |
| `referred_by_code` | string \| null | Kayıt olurken kullanılan kod |
| `founding_member` | bool | Başarılı davet kullanımından sonra `true` |
| `premium_access_until` | timestamp \| null | Premium bitiş tarihi |

### `referrals/{referralId}`

Yalnızca `redeemReferralCode` Cloud Function tarafından yazılır.

| Alan | Tür | Açıklama |
|------|-----|---------|
| `referrer_id` | string | Kodu paylaşan kullanıcının UID'si |
| `referred_id` | string | Kodu kullanan yeni kullanıcının UID'si |
| `redeemed_at` | timestamp | Kullanım zamanı |

### `ai_usage/{uid}/{tier}/{tarih}`

Günlük AI kullanım takibi. `anthropicProxy` tarafından transaction içinde yazılır.

| Alan | Tür | Açıklama |
|------|-----|---------|
| `count` | int | Bugünkü istek sayısı |

`tier` `"quick"` veya `"deep"` değerini alır. `tarih` ISO formatındadır: `YYYY-MM-DD`.

### `articles/{articleId}`

İçerik koleksiyonu. [`functions/scripts/seedArticles.js`](../../functions/scripts/seedArticles.js) tarafından doldurulur.

| Alan | Tür | Açıklama |
|------|-----|---------|
| `id` | string | Kararlı slug (örn. `matcha-latte`) |
| `title` | string | Makale başlığı |
| `body` | string | Makale gövde metni |
| `category` | string | Filtre kategorisi |
| `readTimeMinutes` | int | Tahmini okuma süresi |

---

## Bileşik Dizinler

[`firestore.indexes.json`](../../firestore.indexes.json) dosyasında tanımlanmıştır. Uygulamanın yaptığı sorgular için gereklidir.

| Koleksiyon | Alanlar | Sıra |
|-----------|--------|------|
| `habit_completions` | `userId`, `date` | ASC, ASC |
| `habits` | `userId`, `createdAt` | ASC, ASC |

Dizinleri dağıt:
```bash
firebase deploy --only firestore:indexes
```

---

## Güvenlik Kuralları

[`firestore.rules`](../../firestore.rules) dosyasında tanımlanmıştır. Dağıt:

```bash
firebase deploy --only firestore:rules
```

Temel kurallar:
- Tüm koleksiyonlar `request.auth != null` gerektirir
- Kullanıcıya ait veriler `request.auth.uid == resource.data.userId` gerektirir
- `user_growth` oluşturma: izin verilir (`founding_member == false`, `premium_access_until == null`, `referred_by_code == null`)
- `user_growth` güncelleme/silme: `if false` (yalnızca Admin SDK)
- `referrals` tüm yazmalar: `if false` (yalnızca Admin SDK)
- `articles` yazma: `if false` (yalnızca Admin SDK)

---

## Cloud Functions Dağıtımı

```bash
firebase deploy --only functions
```

Tek fonksiyon dağıtımı:
```bash
firebase deploy --only functions:mintFirebaseToken
```

İlk dağıtımdan önce gizli anahtarları ayarla:
```bash
firebase functions:secrets:set ANTHROPIC_API_KEY
firebase functions:secrets:set SUPABASE_SERVICE_ROLE_KEY
```

---

## Emülatör Yapılandırması

[`firebase.json`](../../firebase.json) dosyasında tanımlanan portlar:

```json
{
  "emulators": {
    "auth": { "port": 9099 },
    "firestore": { "port": 8080 },
    "functions": { "port": 5001 },
    "storage": { "port": 9199 },
    "ui": { "enabled": true, "port": 4000 }
  }
}
```

Tüm emülatörleri başlat:
```bash
firebase emulators:start
```

Flutter uygulaması, `kDebugMode` true olduğunda emülatörlere otomatik olarak bağlanır.

---

## App Check Yapılandırması

Firebase Console → App Check bölümünde:

1. **Android:** Play Integrity sağlayıcısı ile kayıt et
2. **iOS:** App Attest sağlayıcısı ile kayıt et
3. CI/CD için hata ayıklama token'larını `FIREBASE_APP_CHECK_TEST_APP_ID` ortam değişkeni olarak ekle

---

## İçerik Seed'leme

```bash
cd functions
npm run seed:articles
# Seçenekler:
# --prune   articles.json'da bulunmayan Firestore makalelerini sil
```

---

## İlgili Belgeler

- [API.md](API.md) — Cloud Functions istek/yanıt biçimi
- [GUVENLIK.md](GUVENLIK.md) — Firestore kuralları ve App Check
- [DAGITIM.md](DAGITIM.md) — üretim dağıtım kontrol listesi
