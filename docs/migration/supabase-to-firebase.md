# Supabase → Firebase birleştirme

Hedef: runtime'da Supabase'e ihtiyaç kalmaması. İki aşama:

- **Aşama A — profil (bu dal, `feat/firebase-unification`):** Supabase
  `profiles` → Firestore `users/{uid}`. Auth'a dokunulmadı. ADR-0009.
- **Aşama B — kimlik (henüz yapılmadı, karar bekliyor):** Supabase Auth →
  Firebase Auth. Aşağıda taslak.

Aşama A bitince Supabase yalnız kimlik için kalır (giriş, kayıt, Google/Apple,
e-posta onayı, şifre sıfırlama, köprü, hesap silmenin Supabase adımı).

---

## Aşama A — deploy sırası (değiştirmeyin)

Hiçbiri yapılmadı. Her adım önce staging'de (`ilnd-staging-2026`).

1. **Firestore kuralları**
   `firebase deploy --only firestore:rules --project <alias>`
   Eski uygulama etkilenmez: yeni kurallar yalnız izin genişletir (profil
   alanları) ve fotoğraf yazımı aynı kalır.
2. **Migration — kuru çalışma** (yazmaz; prod onayı istemez)
   ```
   cd functions
   gcloud auth application-default login          # depoya kimlik dosyası koymayın
   export SUPABASE_URL=https://<ref>.supabase.co
   read -s SUPABASE_SERVICE_ROLE_KEY && export SUPABASE_SERVICE_ROLE_KEY
   node scripts/migrateSupabaseProfiles.js --project=<id> --report=/tmp/mig-dry.json
   ```
   Özetteki `missingUsers`, `duplicates`, `invalidIds`, `sanitizedProfiles`
   sıfır değilse **durun ve raporu inceleyin** (liste yalnız uid içerir).
3. **Migration — yazma**
   `node scripts/migrateSupabaseProfiles.js --project=<id> --apply [--confirm-prod] --report=/tmp/mig-apply.json`
   `failed > 0` ise çıkış kodu 1; aynı komut güvenle tekrar çalıştırılabilir.
4. **Uygulama sürümü** (web hosting + mağaza). Bu sürüm profili yalnız
   Firestore'dan okur/yazar.
5. **Yeniden migration (yazma)** eski sürümler piyasadan çekilene kadar
   aralıklı: eski sürümde profil düzenleyen kullanıcıların Supabase'teki
   değişiklikleri taşınır. Yeni sürümün yazdığı profiller
   (`profileUpdatedAt` var) ezilmez.

Sıra neden önemli: 4, 3'ten önce giderse yeni sürüm kayıtlı kullanıcının
profilini boş bulur; yeni cihazda onboarding'e düşer ve oradan yazdığı profil
(`profileUpdatedAt`) sonraki migration'ı o kullanıcı için kapatır.

### Script özeti
- Varsayılan **DRY RUN**; `--apply` olmadan hiçbir şey yazılmaz.
- Eşleşme uid ile (köprü aynı uid'i kullanıyor); e-posta eşlemesi yok.
  Firebase Auth'ta kaydı olmayan uid yazılmaz → `missingUsers` (köprüden hiç
  geçmemiş, yani hiç giriş yapmamış hesap). Bu kullanıcılar ilk girişten
  sonra script tekrar çalıştırılınca taşınır.
- `merge` + transaction; mevcut alan silinmez, `profileUpdatedAt` olan
  doküman atlanır (`skipped`).
- Kural sınırı dışındaki değer yazılmaz, `sanitized` listesine girer.
- Çıktı yalnız uid ve sayı; ad/alerji/kilo ve anahtar loglanmaz.
- Kaynak alternatifi: `--input=profiles.json` (SQL editöründen JSON dışa
  aktarım). Anahtar gerekmez.

Örnek özet:
```
{ "mode": "dry-run", "totalProfiles": 5, "matchedUsers": 4, "migrated": 0,
  "wouldMigrate": 3, "skipped": 1, "missingUsers": 1, "duplicates": 0,
  "invalidIds": 0, "sanitizedProfiles": 1, "failed": 0 }
```

### Doğrulama (yapıldı, emülatör/birim)
| Madde | Nerede |
|---|---|
| profil kaydet / yükle / güncelle, yeniden açılışta geri gelme | `test/core/profile_repository_test.dart` |
| onboarding tamamlama (`onboardingDone`/`firstEntryDone`) | aynı dosya + rules testi |
| alan eşlemesi, eski snake_case okunmaz | `test/core/profile_data_test.dart` |
| hesap değişiminde başka hesabın profili yazılmaz | `test/features/onboarding/account_switch_test.dart` |
| başka kullanıcının profili okunamaz/yazılamaz, sınırlar, sahte damga | `functions/test/firestore.rules.test.js` → "users/{uid} profil alanları" |
| migration: kuru çalışma, merge, eksik/çift/geçersiz, tekrar çalıştırma, gizli anahtar loglanmaz, prod koruması | `functions/test/migrateSupabaseProfiles.test.js` |

Signup / login / logout / current user **değişmedi** (Aşama A auth'a dokunmuyor);
mevcut testler (`login_screen_test`, `router_redirect_test`,
`auth_error_mapping_test`, `bridge_session_match_test`) yeşil. Gerçek
cihazda uçtan uca (köprü + Firestore) staging'de manuel doğrulanmalı:
kayıt → onboarding → çıkış → başka cihazda giriş → profil geri geliyor mu.

---

## Aşama B — kimlik taşıma (taslak, onay bekliyor)

Bugün Firebase Auth kullanıcılarının e-postası/şifresi/sağlayıcısı yok (custom
token). Supabase'i kaldırmak şunları gerektirir:

1. Supabase `auth.users` → Firebase Auth `importUsers`: **aynı uid**, e-posta,
   `email_verified`, bcrypt şifre hash'i (`hash: {algorithm: "BCRYPT"}`),
   Google/Apple için `providerData`. Hash'lerin dışa aktarımı SQL erişimi ister;
   yalnız owner yapmalı, dosya depoya girmemeli.
2. Konsol: Firebase Auth'ta E-posta/Şifre, Google, Apple sağlayıcıları;
   yetkili alan adları; e-posta şablonları (onay, şifre sıfırlama) ve
   action URL'i; Apple Services ID / anahtar.
3. İstemci: `AuthNotifier` → `firebase_auth` (signIn/signUp/Google/Apple/
   reset/updatePassword/confirm), `AuthAuthenticated.user` tipi (şu an
   Supabase `User`), `mapSupabaseAuthError` → Firebase hata kodları, deep link
   akışı (`authDeepLinkRedirect`, token_hash yolu).
4. Sunucu: `isBridgedSession` (denetim H-5) yeni sağlayıcıları kabul edecek
   şekilde yeniden tasarlanmalı — anonim ve kontrolsüz e-posta kaydı açık
   kalmamalı (App Check + e-posta doğrulama şartı); `mintFirebaseToken`
   kaldırılır; `deleteAccount`'un Supabase adımı çıkar.
5. Geçiş dönemi: eski sürümler Supabase ile girer ve köprüden geçer; köprü
   eski sürümler bitene kadar açık kalmalı. Şifre değiştiren kullanıcı iki
   sistemde ayrışır → kesme tarihi / zorunlu güncelleme (M-9) gerekir.

---

## Supabase temizlik envanteri (SİLİNMEDİ — Aşama B + doğrulama sonrası)

**Aşama A sonrası artık gereksiz (profil):**
- `supabase/migrations/20260913000000_profiles_rls.sql`, `supabase/tests/profiles_rls.test.sql`
- `functions/test/supabaseMigration.test.js` (SQL dosyasını kilitliyor)
- `docs/db/profiles_onboarding.sql`
- `functions/accountDeletion.js` → `profiles` satırı silme isteği (tablo
  silinene kadar KALMALI: eski satırda kişisel veri var)
- Supabase `public.profiles` tablosu — migration doğrulanıp yedek alındıktan sonra

**Aşama B ile kalkacaklar (kimlik):**
- Dependency: `supabase_flutter` (pubspec.yaml)
- Import: `lib/main.dart`, `lib/features/auth/auth_provider.dart`,
  testler (`login_screen`, `account_switch`, `preferences_screen`,
  `profile_layout`, `ada_layout`, `frontend_state_regression`,
  `router_redirect`, `auth_error_mapping`)
- Init: `Supabase.initialize` + `_StartupFailureApp` (`lib/main.dart`)
- Config: `AppConfig.supabaseUrl/supabaseAnonKey/isSupabaseConfigured`,
  `AUTH_BRIDGE_URL`
- Env: `.env`/`.env.example` `SUPABASE_URL`, `SUPABASE_ANON_KEY`;
  `functions/.env(.example)` `SUPABASE_URL`; Secret Manager `SUPABASE_SERVICE_ROLE_KEY`
- Servisler: `lib/core/services/firebase_auth_bridge.dart`,
  `functions/supabaseClaims.js`, `mintFirebaseToken` (functions/index.js),
  `deleteAccount` Supabase adımı, `test/core/bridge_session_match_test.dart`,
  `functions/test/supabaseClaims.test.js`, `helpers.js` `provider: "supabase"` claim'i
- Platform: AndroidManifest / Info.plist e-posta deep link girdileri
  (Firebase action URL'ine göre yeniden değerlendirilir)
- Metin: `legal_content.dart` (gizlilik politikasında Supabase), l10n
  "Supabase init failed" açıklaması, README/DEPLOYMENT/docs/en/*
- `supabase/` klasörü ve Supabase projeleri (prod `qygmovihgbpmhtlidfov`,
  staging `ocepgiootcsdqcqushqi`) — en son, yedekten sonra
