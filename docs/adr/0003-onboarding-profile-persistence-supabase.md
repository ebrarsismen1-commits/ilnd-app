# ADR-0003: Onboarding & profil kalıcılığı Supabase `profiles`'a taşınır

**Status:** Accepted
**Date:** 2026-07-07

## Decision
Onboarding tamamlanma bayrakları (`onboarding_done`, `first_entry_done`) ve
profil verisi (ad, hedefler, aktivite seviyesi, beslenme, alerjiler, yaş/boy/kilo)
gerçeğin kaynağı olarak Supabase `profiles` tablosunda tutulur. Yerel
SharedPreferences bir *cache* katmanına indirgenir: girişte sunucudan hidratlanır,
onboarding tamamlanınca sunucuya flush edilir.

## Context
Tüm onboarding durumu ve ILND hafızası cihaz-yerel SharedPreferences'ta
tutuluyordu (bkz. `ilnd_memory.dart` "ileride Firestore'a senkronize edilecek"
notu). Sonuç: web'de (boş localStorage) veya yeni cihazda zaten kayıtlı bir
kullanıcı `onboarding_done=false` olduğu için router tarafından tekrar
onboarding'e atılıyordu ("her seferinde baştan"). Beslenme/alerji de aynı
nedenle cihazlar arası taşınmıyordu. Kimlik zaten Supabase'de (ADR-0001) ve
`profiles` tablosu kayıt anında `name` için kullanılıyordu.

## Alternatives
1. **Firestore `users/{uid}`** — journal/food verisinin yaşadığı yer. Elenme
   nedeni: FirebaseAuthBridge köprüsü açılmadan yazma/okuma permission-denied
   olur (Sert Kural #2'nin nedeni); profil hidratlaması girişte köprüyü beklemek
   zorunda kalır, yani "stream hatadan sonra kendini yenilemez" tuzağına açık.
2. **Yalnız uid-bazlı yerel bayraklar** — bayrakları uid'e göre anahtarlamak.
   Elenme nedeni: hâlâ cihaz-yerel; web/yeni cihaz bug'ını çözmez.
3. **Minimal (yalnız `profiles` satırı var mı kontrolü)** — sadece bayrağı
   backfill et, alanları taşıma. Elenme nedeni: kullanıcı A (tam senkron) istedi;
   hedef/beslenme/alerji cihazlar arası taşınmalı.

## Pros / Cons
+ Auth ile aynı sistem; uid RLS ile satır-bazlı korunuyor, ekstra köprü yok
+ `profiles` zaten var ve kullanımda; yalnız kolon eklenir, yeni tablo yok
+ Yerel cache offline ilk-açılışta anında UI verir, sunucu geldiğinde düzeltir
− `profiles` şeması Supabase panelinden elle migrate edilmeli (SQL: `docs/db/profiles_onboarding.sql`)
− Girişte bir hidratlama penceresi (kısa splash beklemesi) router'a eklenir
− Yerel-yalnız eski veri (henüz sunucuya yazılmamış hedef/alerji) yalnız o cihazdan backfill edilir

## Reason
Auth zaten Supabase; profil metadata'sını aynı uid-scoped tabloya koymak, veriyi
Firestore köprüsünün zamanlama riskine sokmadan cihazlar arası taşınabilir kılar.
Yeni tablo/migration riski minimum (yalnız kolon ekleme, `if not exists`).

## Consequences
- `profiles` tablosuna yeni kolonlar eklenmeli (panel adımı — ship kontrol listesine girer).
- Uygulama kodu eksik kolona toleranslı olmalı: okuma her alanda `?? default`,
  yazma try/catch (kolon yoksa onboarding'i bloklamaz). `doc.data()!` yasağının
  Supabase karşılığı: `row as Map? ?? const {}`.
- Girişte `profileHydrationProvider` çözülene kadar router authenticated
  kullanıcıyı yönlendirmez (splash bekler).
- Yeni kullanıcı-bağlı provider olarak `profileHydrationProvider` hem
  `authNotifierProvider`'ı hem uid'i izler (Sert Kural #2).

## Future Impact
ILND hafızası (facts/notes) da ileride aynı `profiles`/ayrı tabloya taşınabilir
(premium: uzun hafıza). Tek-auth'a geçilirse (ADR-0001 Future Impact) bu tablo
Firestore'a veya Postgres-only modele göç eder; geri alma maliyeti düşük çünkü
yerel cache katmanı korunuyor.
