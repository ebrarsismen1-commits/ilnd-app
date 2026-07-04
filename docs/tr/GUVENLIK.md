# Güvenlik Kılavuzu

## Tehdit Modeli

ilnd bir tüketici refah uygulamasıdır. Temel güvenlik endişeleri:

1. **Premium atlama** — kullanıcıların kendilerine ücretsiz premium erişim vermesi
2. **API anahtarı ifşası** — Anthropic anahtarının istemci binary'sine sızması
3. **Veri izolasyonu** — bir kullanıcının başka bir kullanıcının verilerini okuması/değiştirmesi
4. **Yapay zeka maliyet kötüye kullanımı** — günlük AI istek kotasını aşma
5. **Hesap ele geçirme** — yetkisiz veri silme veya sızdırma

Bu beş tehdidin tamamı mevcut mimaride ele alınmıştır.

---

## Kritik Düzeltmeler (v1.0)

### 1. Premium Kendine Verme (KRİTİK — Düzeltildi)

**Önceki durum:** `user_growth` koleksiyonu herkese açık yazılabilirdi. Herhangi bir kimliği doğrulanmış kullanıcı, doğrudan istemciden `{founding_member: true, premium_access_until: <uzak gelecek>}` güncelleyebilirdi.

**Düzeltme:** Firestore kuralları artık `founding_member`, `premium_access_until` ve `referred_by_code` alanlarına tüm istemci yazmalarını reddeder. Bu alanlar yalnızca Firebase Admin SDK çalıştıran `redeemReferralCode` Cloud Function tarafından yazılır.

```javascript
// firestore.rules — user_growth
allow create: if request.auth != null
  && request.auth.uid == userId
  && request.resource.data.founding_member == false
  && request.resource.data.premium_access_until == null
  && request.resource.data.referred_by_code == null;

allow update: if false;  // Yalnızca Admin SDK
allow delete: if false;
```

### 2. İstemci Binary'sinde Anthropic API Anahtarı (KRİTİK — Düzeltildi)

**Önceki durum:** Anahtar `--dart-define=ANTHROPIC_API_KEY=sk-ant-...` ile iletildi ve uygulama binary'sine derlendi. Standart APK/IPA analiz araçlarıyla çıkarılabilirdi.

**Düzeltme:** Anahtar tüm istemci tarafı kodundan kaldırıldı. Tüm AI istekleri, anahtarı Firebase Secret Manager'da saklayan `anthropicProxy` Cloud Function üzerinden geçer.

---

## Firestore Güvenlik Kuralları

| Koleksiyon | Okuma | Yazma |
|-----------|-------|-------|
| `users/{uid}` | Yalnızca sahip | Yalnızca sahip |
| `users/{uid}/journal_entries` | Yalnızca sahip | Yalnızca sahip |
| `habits` | Yalnızca sahip (userId eşleşmesi) | Yalnızca sahip |
| `habit_completions` | Yalnızca sahip | Yalnızca sahip |
| `user_growth` | Yalnızca sahip | Oluşturma (kısıtlı alanlar), güncelleme/silme yok |
| `referrals` | — | Yalnızca Admin SDK |
| `articles` | Kimliği doğrulanmış herkes | Yalnızca Admin SDK |
| `ai_usage` | Yalnızca sahip | Cloud Function (Admin SDK) |

Kuralları yerel ortamda doğrula:
```bash
firebase emulators:start
# Kurallar emülatörde üretimle aynı şekilde uygulanır
```

---

## Firebase App Check

App Check, isteklerin gerçek uygulama binary'sinden geldiğini doğrular.

**Yapılandırma:**

| Platform | Sağlayıcı (Yayın) | Sağlayıcı (Hata Ayıklama) |
|----------|------------------|--------------------------|
| Android | Play Integrity | Debug sağlayıcı |
| iOS | App Attest | Debug sağlayıcı |

Zorunlu tutulan fonksiyonlar:
- `anthropicProxy`
- `redeemReferralCode`
- `deleteAccount`

`mintFirebaseToken`'da **zorunlu tutulmaz** — kasıtlı olarak. Cihaz doğrulama başarısız olursa kullanıcılar girişe erişimi kaybedebilir.

---

## Yapay Zeka Kullanım Kotaları

`anthropicProxy`'de Firestore transaction'ı ile uygulanan günlük limitler:

```javascript
const TIER_CONFIG = {
  quick: { model: 'claude-haiku-4-5', maxTokens: 512, dailyLimit: 300 },
  deep:  { model: 'claude-sonnet-4-6', maxTokens: 1024, dailyLimit: 60 },
};
```

Transaction, istek Anthropic'e iletilmeden önce `ai_usage/{uid}/{tier}/{bugün}` sayacını atomik olarak okur ve artırır. İstemci farklı bir model veya token sayısı sağlayarak bunu atlayamaz.

---

## Gizli Anahtar Yönetimi

| Gizli Anahtar | Depolama | Erişim |
|--------------|---------|--------|
| Anthropic API anahtarı | Firebase Secret Manager | Yalnızca `anthropicProxy` |
| Supabase service role key | Firebase Secret Manager | Yalnızca `deleteAccount` |
| Supabase anon key | İstemci `.env` | Kasıtlı olarak açık (RLS uygulanır) |
| Android keystore | GitHub Actions secret (base64) | Yalnızca yayın iş akışı |

**Asla commit etme:**
- `.env` dosyaları
- `google-services.json`
- `GoogleService-Info.plist`
- `*.keystore` / `*.jks` / `key.properties`

Tümü [`.gitignore`](../../.gitignore) kapsamındadır.

Cloud Function gizli anahtarlarını ayarla:
```bash
firebase functions:secrets:set ANTHROPIC_API_KEY
firebase functions:secrets:set SUPABASE_SERVICE_ROLE_KEY
```

---

## Hesap Silme

`deleteAccount` Cloud Function basamaklı silme yapar:

1. `users/{uid}/` altındaki tüm Firestore belgeleri
2. `user_growth/{uid}` belgesi
3. `referred_id == uid` olan `referrals` belgeleri
4. `users/{uid}/` altındaki Firebase Storage dosyaları
5. Supabase Auth kullanıcısı (en iyi çaba — hata loglanır ama işlemi durdurmaz)
6. Firebase Auth kullanıcısı

[Apple App Store Kılavuzu 5.1.1(v)](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage) tarafından zorunlu tutulmaktadır.

---

## Crashlytics Gizliliği

Crashlytics hata ayıklama modunda devre dışıdır:

```dart
await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
```

Crashlytics'e kasıtlı olarak kişisel veri gönderilmez. Yalnızca yayın derlemelerinde yığın izleri ve cihaz meta verileri toplanır.

---

## Güvenlik Açığı Bildirimi

Bir güvenlik açığı keşfedersen, proje sorumlusuyla doğrudan iletişime geç (herkese açık GitHub sorunu açma). Şunları ekle:
- Güvenlik açığının açıklaması
- Yeniden üretme adımları
- Potansiyel etki değerlendirmesi

---

## İlgili Belgeler

- [FIREBASE.md](FIREBASE.md) — Firestore kuralları ve dizinler
- [API.md](API.md) — Cloud Functions kimlik doğrulama detayları
- [DAGITIM.md](DAGITIM.md) — Üretimde App Check yapılandırması
