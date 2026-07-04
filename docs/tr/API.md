# Cloud Functions API Referansı

Tüm fonksiyonlar, `ilnd-app-8dcbd` projesinde dağıtılan Firebase Cloud Functions v2'dir. Temel URL biçimi:

```
https://<bölge>-ilnd-app-8dcbd.cloudfunctions.net/<fonksiyonAdi>
```

İstemci, `AppConfig._siblingFunctionUrl()` aracılığıyla kardeş fonksiyon URL'lerini `AUTH_BRIDGE_URL`'den türetir. Bkz. [`lib/core/services/app_config.dart`](../../lib/core/services/app_config.dart).

---

## Kimlik Doğrulama

Dört fonksiyondan üçü, Authorization başlığında **Firebase ID token** gerektirir:

```
Authorization: Bearer <firebase-id-token>
```

Şu şekilde elde edilir:
```dart
final token = await FirebaseAuth.instance.currentUser!.getIdToken();
```

Üç fonksiyon ayrıca **Firebase App Check token** gerektirir:
```
X-Firebase-AppCheck: <app-check-token>
```

---

## `POST /mintFirebaseToken`

Bir Supabase JWT'sini doğrular ve Firebase özel token'ı döner. İki kimlik doğrulama sistemini köprülemek için giriş sırasında kullanılır.

**App Check:** Gerekli değil (kasıtlı — bkz. [GUVENLIK.md](GUVENLIK.md))

**İstek gövdesi:**
```json
{
  "supabaseToken": "<supabase-jwt>"
}
```

**Yanıt 200:**
```json
{
  "firebaseToken": "<firebase-ozel-token>"
}
```

**Yanıt 401:** Geçersiz veya süresi dolmuş Supabase JWT.

---

## `POST /anthropicProxy`

AI isteklerini Anthropic API'sine proxy'ler. Kullanıcı başına günlük kotaları sunucu tarafında uygular. İstemci model veya token sınırlarını geçersiz kılamaz.

**App Check:** Gerekli

**İstek gövdesi:**
```json
{
  "tier": "quick",
  "messages": [
    { "role": "user", "content": "Bugün nasıl hissediyorum?" }
  ],
  "systemPrompt": "Sen ILND, kişisel bir refah asistanısın."
}
```

**Katman değerleri:**

| Katman | Model | Maks Token | Günlük Limit |
|--------|-------|-----------|-------------|
| `quick` | `claude-haiku-4-5` | 512 | 300/gün |
| `deep` | `claude-sonnet-4-6` | 1024 | 60/gün |

**Yanıt 200:** Anthropic API yanıt nesnesi (doğrudan iletilir)

**Yanıt 429:** Bu katman için günlük kullanım kotası aşıldı.

**Yanıt 400:** `messages` eksik, bilinmeyen `tier`.

**Yanıt 401:** Geçersiz veya eksik Firebase ID token.

---

## `POST /redeemReferralCode`

Kimliği doğrulanmış kullanıcı için bir davet kodu kullanır. Atomik olarak:
- Kodun var olduğunu ve bu kullanıcı tarafından daha önce kullanılmadığını doğrular
- Kendine davet engeller
- Davet edene 7 günlük premium verir (mevcut `premium_access_until` üzerine eklenir)
- Kullananı `founding_member: true` olarak işaretler
- Bir `referrals` belgesi kaydeder

**App Check:** Gerekli

**İstek gövdesi:**
```json
{
  "code": "ILND-XXXX"
}
```

**Yanıt 200 (başarılı):**
```json
{ "status": "redeemed" }
```

**Yanıt 200 (zaten kullanıldı):**
```json
{ "status": "already-redeemed" }
```

**Yanıt 200 (kendine davet):**
```json
{ "status": "self-referral" }
```

---

## `POST /deleteAccount`

Basamaklı hesap silme. Firestore, Storage, Supabase ve Firebase Auth genelinde tüm kullanıcı verilerini siler.

**App Check:** Gerekli

**Silme sırası:**
1. `users/{uid}` alt koleksiyon belgeleri
2. `user_growth/{uid}` belgesi
3. `referred_id == uid` olan `referrals` belgeleri
4. `users/{uid}/` altındaki Firebase Storage dosyaları
5. Supabase Auth kullanıcısı (en iyi çaba)
6. Firebase Auth kullanıcısı

**Yanıt 200:**
```json
{ "status": "deleted" }
```

---

## Hata Yanıt Biçimi

```json
{
  "error": "İnsan tarafından okunabilir hata mesajı"
}
```

HTTP durum kodları:
| Kod | Anlam |
|-----|-------|
| 200 | Başarılı (yumuşak başarısızlık durumları dahil) |
| 400 | Hatalı istek |
| 401 | Kimlik doğrulama başarısız |
| 429 | Hız sınırı aşıldı |
| 500 | Beklenmedik sunucu hatası |

---

## İlgili Belgeler

- [GUVENLIK.md](GUVENLIK.md) — App Check ve gizli anahtar yönetimi
- [FIREBASE.md](FIREBASE.md) — Bu fonksiyonların yazdığı Firestore koleksiyonları
- [TEST.md](TEST.md) — Cloud Functions test paketi
