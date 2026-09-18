# ADR-0010: Kimlik doğrudan Firebase Auth (Supabase Auth ve köprü kaldırılıyor)

**Status:** Accepted (kod) · Deploy bekliyor
**Date:** 2026-09-18
**Supersedes:** ADR-0001

## Decision
Kimlik doğrulamanın tek kaynağı Firebase Auth. Uygulama `firebase_auth` ile
e-posta/şifre, Google ve Apple girişini doğrudan yapar; `supabase_flutter`
bağımlılığı, `Supabase.initialize`, `FirebaseAuthBridge` ve `mintFirebaseToken`
kaldırıldı. Profil verisi zaten Firestore'da (ADR-0009). Uygulama runtime'da
Supabase'e ihtiyaç duymaz.

Owner kararları (2026-09-18):
1. **Şifreler taşınmaz.** Supabase kullanıcıları Firebase'e aynı uid, e-posta
   ve doğrulama durumuyla, şifresiz aktarılır
   (`functions/scripts/importSupabaseUsers.js`). E-posta/şifre kullanıcıları
   ilk girişte "şifremi unuttum" ile yeni şifre belirler; yanlış şifre metni
   bunu hatırlatır.
2. **Sert kesme.** Köprü kalkar; eski sürümler giriş yapamaz.
3. **E-posta doğrulaması zorunlu kalır.** Firebase doğrulanmamış hesabın
   girişini engellemediği için istemci o oturumu kapatır ve onay mailini
   yeniden gönderir; sunucu uçları da doğrulanmamış e-posta oturumunu reddeder.

Prod Supabase yapısı (yalnız metadata, 2026-09-18): tek tablo `public.profiles`
(1 satır), storage bucket / edge function / realtime / auth trigger yok,
yalnız `email` sağlayıcısı. Google/Apple kimliği bağlamak gerekmedi.

## Değişenler
- **İstemci:** `AuthNotifier` → `FirebaseAuth` (`userChanges`), durumlarda
  Supabase `User` yerine `AuthUser {id, email}`. Hata eşleme Firebase
  kodlarıyla (`mapFirebaseAuthError`). Şifre sıfırlama Firebase'in kendi işlem
  sayfasında biter (token_hash akışı kalktı). Firebase başlatılamazsa
  "başlatılamadı" ekranı (eskiden Supabase için).
- **Fonksiyon adresleri:** `FUNCTIONS_BASE_URL`; eski `.env`'deki
  `AUTH_BRIDGE_URL`'den de türetilir, yani .env güncellenmeden derlenen sürüm
  AI/davet/hesap silmeyi kaybetmez.
- **Sunucu kapısı (H-5):** `functions/authClaims.js` — yalnız doğrulanmış
  `password`, `google.com`, `apple.com`. Anonim ve custom token (eski köprü
  dahil) reddedilir.
- **Hesap silme (H-3):** köprü, silme istenmiş uid'e oturum açmıyordu. Artık
  ilk adım Firebase kullanıcısını **devre dışı** bırakmak: yeni giriş ve token
  yenileme reddedilir. Refresh token iptal edilmez; elindeki ID token (≤1 saat)
  ile kullanıcı tekrar deneyebilir, gerisi `retryPendingDeletions`. Not: Auth
  emülatörü devre dışı hesabın token'ını da reddeder (üretim etmez); testler
  bunu modül düzeyinde doğrular. Supabase silme adımı Supabase projesi
  kapatılana kadar kalır (eski kayıtlar).

## Consequences
+ Tek kimlik sistemi; iki oturumun ayrışması (M-8) sınıfı hata ortadan kalkar.
+ Firebase oturumu anında hazır; "köprü girişi bekleniyor" gecikmesi yok.
− Taşınan e-posta kullanıcıları bir kez şifre sıfırlamak zorunda.
− Eski uygulama sürümleri giriş yapamaz (sert kesme). Minimum sürüm kapısı
  (M-9) yok: eski sürümdeki kullanıcı yalnız giriş hatası görür.
− Firestore kuralları e-posta doğrulamasını ayrıca istemiyor: public API
  key ile açılmış doğrulanmamış bir hesap kendi `users/{uid}` ağacına
  yazabilir (uçlar ve diğer kullanıcıların verisi kapalı). Kapatmak için
  kurallara `email_verified` şartı ya da Identity Platform blocking function
  (`beforeUserSignedIn`) gerekir; ayrı karar.
− `AuthPasswordRecovery` durumu ve yeni-şifre ekranı artık üretilmiyor; Supabase
  temizliğinde kaldırılacak.
