# ADR-0009: Profil verisinin kaynağı Firestore `users/{uid}` (Supabase `profiles` bırakılıyor)

**Status:** Accepted (kod) · Deploy bekliyor
**Date:** 2026-09-18
**Supersedes:** ADR-0003

## Decision
Onboarding bayrakları ve profil verisi Supabase `profiles` yerine Firestore
`users/{uid}` dokümanının üst seviye alanlarında tutulur. Bu doküman zaten
profil fotoğrafını (`photoBase64`) taşıyor; tüm yazımlar `merge`.

| Supabase `profiles` | Firestore `users/{uid}` |
|---|---|
| `name` | `name` |
| `onboarding_done` | `onboardingDone` |
| `first_entry_done` | `firstEntryDone` |
| `goals` | `goals` |
| `activity_level` | `activityLevel` |
| `diet` | `diet` |
| `allergies` | `allergies` |
| `age` | `age` (bkz. aşağıda) |
| `height` | `heightCm` |
| `weight` | `weightKg` |
| `updated_at` | taşınmaz; yerine `profileUpdatedAt` (istemci, sunucu saati) |
| — | `profileMigratedAt` / `profileMigratedFrom` (yalnız migration script'i) |

Adlandırma Firestore'daki mevcut camelCase kuralına uyar (`photoUpdatedAt`,
`createdAt`). `profileUpdatedAt` adı `photoUpdatedAt` ile paralel: aynı
dokümanda iki ayrı kaynağın damgası karışmasın.

## Context
Kullanıcının gerçek verisi (günlük, öğün, ada, alışkanlıklar…) zaten
Firestore'da; yalnız profil Supabase'teydi. Supabase'i kaldırma yolunun ilk,
auth'a dokunmayan adımı bu. Uid'ler aynı: köprü (`mintFirebaseToken`) Firebase
custom token'ını Supabase JWT `sub`'ıyla üretiyor, yani `profiles.id` ===
Firebase uid ve taşıma e-posta eşlemesi gerektirmiyor.

## Consequences
+ Profil okuma/yazma runtime'da Supabase'e ihtiyaç duymuyor.
+ Firestore kuralları profil alanlarını tip ve sınırla doğruluyor
  (`profiles_field_bounds` ile aynı sınırlar); sahibi dışında kimse okuyamıyor.
+ `profileUpdatedAt == request.time` zorunlu; istemci sahte damgayla
  migration'ın "Firestore daha yeni" kararını etkileyemiyor.
− Profil okuması artık Firebase köprü girişine bağlı. `FirestoreProfileStore`
  köprüyü 15 sn bekler; gelmezse "sunucu yanıt vermedi" yoluna düşer (ADR-0003'teki
  fetch hatasıyla aynı davranış: onboarding bloklanmaz).
− Deploy sırası şart: kurallar → migration → uygulama sürümü
  (docs/migration/supabase-to-firebase.md). Sıra bozulursa yeni sürüm
  profili boş görür ve yeni cihazdaki kayıtlı kullanıcıyı onboarding'e alır.
− Eski uygulama sürümleri Supabase'e yazmaya devam eder; script tekrar
  çalıştırılabilir (istemcinin yazdığı profili ezmez).

## `age` hakkında
`age` zamanla eskiyen bir değer (yazıldığı günün yaşı). Uygulama ona bağlı
olduğu için taşımada korundu. Öneri: onboarding'de `birthYear` sorulsun,
`age` okunurken `birthYear`'dan türetilsin; mevcut `age` + `profileUpdatedAt`
(ya da `profileMigratedAt`) ile yaklaşık `birthYear` tek seferlik doldurulabilir.
Bu ayrı bir ürün kararı; bu ADR kapsamında yapılmadı.
