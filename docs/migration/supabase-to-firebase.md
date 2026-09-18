# Supabase → Firebase birleştirme

Hedef: runtime'da Supabase'e hiç ihtiyaç kalmaması. Kod tarafı tamam:

- **Aşama A — profil** (`feat/firebase-unification`, ADR-0009): Supabase
  `profiles` → Firestore `users/{uid}`.
- **Aşama B — kimlik** (`feat/firebase-auth`, ADR-0010): Supabase Auth +
  köprü → doğrudan Firebase Auth. `supabase_flutter` kaldırıldı.

Prod Supabase'te taşınacak her şey (yapı taraması, 2026-09-18): `auth.users`
(yalnız e-posta sağlayıcısı) ve `public.profiles` (1 satır). Storage, edge
function, realtime, trigger yok.

Owner kararları: şifre taşınmaz (kullanıcı sıfırlar) · sert kesme (eski
sürümler giriş yapamaz) · e-posta doğrulaması zorunlu.

---

## Deploy sırası (hiçbiri yapılmadı; önce staging `ilnd-staging-2026`)

1. **Firebase Console → Authentication** (owner)
   - Sign-in method: **Email/Password** açık. Google/Apple kullanılacaksa
     onlar da (Google için `GOOGLE_SERVER_CLIENT_ID` = bu projenin Web client
     ID'si; Apple için Services ID + anahtar).
   - Authorized domains: web origin'leri.
   - Templates: e-posta doğrulama + şifre sıfırlama, dil TR.
2. **Firestore kuralları** — `firebase deploy --only firestore:rules`.
   Eski uygulamayı bozmaz (yalnız profil alanlarına izin ekler).
3. **Kullanıcılar** (şifresiz, aynı uid):
   ```
   cd functions
   gcloud auth application-default login        # kimlik dosyası depoya girmez
   export SUPABASE_URL=https://<ref>.supabase.co
   read -s SUPABASE_SERVICE_ROLE_KEY && export SUPABASE_SERVICE_ROLE_KEY
   node scripts/importSupabaseUsers.js --project=<id> --report=/tmp/users-dry.json
   # conflicts / duplicates / noEmail / unsupportedProvider sıfır değilse DUR
   node scripts/importSupabaseUsers.js --project=<id> --apply [--confirm-prod]
   ```
4. **Profiller**:
   ```
   node scripts/migrateSupabaseProfiles.js --project=<id> --report=/tmp/prof-dry.json
   node scripts/migrateSupabaseProfiles.js --project=<id> --apply [--confirm-prod]
   ```
5. **Kesme — aynı pencerede, arka arkaya:**
   - 3 ve 4'ü `--apply` ile **bir kez daha** çalıştırın (arada eski
     uygulamayla kayıt olan / profil değiştiren kullanıcılar için; ikisi de
     tekrar çalıştırmaya güvenli).
   - `firebase deploy --only functions` — yeni kimlik kapısı; `mintFirebaseToken`
     silinir (CLI onay ister). Bu andan sonra eski sürümler hiçbir uca
     ulaşamaz.
   - `.env`'e `FUNCTIONS_BASE_URL` (yoksa eski `AUTH_BRIDGE_URL` de iş görür),
     `flutter build web --release --dart-define-from-file=.env`,
     `grep -c "<project-id>" build/web/main.dart.js` ≠ 0, hosting deploy.
   - Mobil sürüm mağazaya.
6. **Doğrulama** (gerçek cihaz + web): yeni kayıt → onay maili → onay →
   giriş → onboarding → çıkış → başka cihazda giriş → profil geri geliyor;
   taşınmış hesap: yanlış şifre metni → "şifremi unuttum" → yeni şifre →
   giriş → profil geri geliyor; hesap silme.
7. **Supabase kapatma** — aşağıdaki envanter, doğrulamadan ve yedekten sonra.

Neden sıra: 3 olmadan taşınmış kullanıcı yeni sürümde "hesap yok" yaşar
(aynı e-postayla yeni kayıt olursa YENİ uid alır ve eski verisinden kopar);
4 olmadan profil boş gelir ve kullanıcı onboarding'e düşer.

### Scriptlerin ortak özellikleri
- Varsayılan **DRY RUN**; `--apply` olmadan yazmaz, prod'da `--confirm-prod`.
- Eşleşme uid ile; e-posta eşlemesi yok. Çakışan / çift / belirsiz kayıt
  yazılmaz, listelenir.
- Mevcut Firebase kaydı silinmez: köprünün bıraktığı e-postasız kullanıcıya
  yalnız e-posta eklenir; profil `merge` ile yazılır, istemcinin yazdığı
  profil (`profileUpdatedAt`) ezilmez.
- Çıktı yalnız uid ve sayı; e-posta, ad, sağlık verisi, anahtar loglanmaz.

---

## Doğrulama (yapıldı)

| Madde | Nerede |
|---|---|
| signup (onay maili, oturum kapanır), login, logout, current user, restart sonrası oturum | `test/features/auth/auth_notifier_test.dart` |
| doğrulanmamış e-postayla giriş reddedilir, Google/Apple beklemez | aynı dosya |
| Firebase hata kodları → UI hata kodları | `test/features/auth/auth_error_mapping_test.dart` |
| profil kaydet / yükle / güncelle / restart / onboarding bayrakları | `test/core/profile_repository_test.dart`, `profile_data_test.dart` |
| başka hesabın profili yazılmaz (hesap değişimi) | `test/features/onboarding/account_switch_test.dart` |
| Firestore kuralları: başka kullanıcı okuyamaz/yazamaz, sınırlar, sahte damga | `functions/test/firestore.rules.test.js` |
| uçlar: anonim, eski köprü token'ı, doğrulanmamış e-posta reddedilir | `functions/test/backendAuth.test.js`, `authClaims.test.js` |
| hesap silme yarım kalırsa hesap kilitlenir, tamamlanır | `functions/test/deleteAccount.test.js` |
| kullanıcı ve profil taşıma scriptleri | `functions/test/importSupabaseUsers.test.js`, `migrateSupabaseProfiles.test.js` |

Emülatör/birim dışı, **yapılmadı**: gerçek Firebase projesinde uçtan uca akış
(adım 6), Google/Apple girişi (konsol ayarı gerekiyor).

---

## Supabase temizlik envanteri (SİLİNMEDİ)

Uygulama runtime'da artık Supabase kullanmıyor. Kalanlar (Supabase projesi
kapatılırken, yedekten sonra):

- `supabase/` klasörü (migrations, tests), `docs/db/profiles_onboarding.sql`,
  `functions/test/supabaseMigration.test.js`
- `functions/accountDeletion.js` Supabase adımı + `SUPABASE_URL`
  (functions/.env) + `SUPABASE_SERVICE_ROLE_KEY` secret'ı + `deleteAccount.test.js`
  içindeki sahte Supabase sunucusu — proje kapanana kadar KALMALI (eski
  kayıtları silmek için)
- İki migration script'i ve testleri (taşıma bitince)
- `functions/package.json` → `jose` bağımlılığı (artık kullanılmıyor; lockfile
  ile birlikte kaldırılmalı)
- `AuthPasswordRecovery`, `new_password_screen.dart`, router'daki recovery
  kilidi, `authLinkErrorProvider` / `resetLinkInvalid` (Supabase e-posta
  linki akışı)
- AndroidManifest / Info.plist `com.ilnd.app://login-callback` deep link
  girdileri ve `deep_link_config_test.dart`
- Yorumlar ve dokümanlar: README, docs/en/*, docs/tr/*, ARCHITECTURE_BLUEPRINT,
  DIFFERENTIATION, APP_STORE_CHECKLIST (veri paylaşımı beyanından Supabase
  çıkarılmalı — mağaza formu owner'da)
- Supabase projeleri: prod `qygmovihgbpmhtlidfov`, staging `ocepgiootcsdqcqushqi`
