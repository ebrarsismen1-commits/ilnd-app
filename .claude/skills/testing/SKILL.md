---
name: testing
description: Test stratejisi ve bu repo'ya özgü test desenleri. Neyi hangi seviyede test edeceğine karar verir; bilinen test tuzaklarının çözümlerini içerir.
---

# testing — Test Stratejisi

## Ne Test Edilir (karar ağacı)
```
Değişiklik neye dokunuyor?
├─ Para/veri/güvenlik/gizlilik (auth, billing, memory, rules) → TEST ZORUNLU, PR'sız geçmez
├─ Saf mantık (validators, copy, meter, streak)              → unit test (en ucuz, önce bu)
├─ Provider/Notifier davranışı                               → notifier testi (ProviderScope/doğrudan)
├─ Ekran davranışı (validasyon, durum geçişi)                → widget test
└─ Salt görsel/kozmetik                                      → test yok; ui checklist yeter
Golden test KULLANMA (font kısıtı ortamda kırılgan) — davranışı assert et, pikseli değil.
```

## Bu Repo'nun Desenleri (kopyala-uyarla)
- **Supabase gereken test:** `setUpAll`: `SharedPreferences.setMockInitialValues({})` →
  `Supabase.initialize(url: 'https://example.supabase.co', publishableKey: 'test-anon-key')`
- **google_fonts:** her zaman `testWidgets` + `GoogleFonts.config.allowRuntimeFetching = false`
- **Prefs tabanlı notifier:** mock prefs + doğrudan notifier kur (bkz. ilnd_memory_scoping_test)
- **Ekran pump:** `ProviderScope(overrides:[sharedPreferencesProvider...])` +
  `MaterialApp(locale, delegates)`; `pumpAndSettle` YASAK (sonsuz animasyon) →
  `pump()` + `pump(100ms)`
- **l10n assert:** `lookupAppLocalizations(Locale('tr'))` ile metni anahtar üzerinden bul

## Kalite Kuralları
- Test, davranışı belgeler: adı "neyi garanti ettiğini" söyler
- Bug fix testi önce KIRMIZI görülür (yoksa neyi kanıtladığı belirsiz)
- Flaky test tespit edilirse silinmez, kök nedeni `fix` akışına girer

## Definition of Done
- [ ] Karar ağacına göre gereken seviye(ler) yazıldı ve yeşil
- [ ] Yeni desen çıktıysa bu dosyaya eklendi
- [ ] Kapı yeşil
