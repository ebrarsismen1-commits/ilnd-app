---
name: ship
description: Yayın hazırlığı ve release doğrulaması. Otomatik kapılar + üretim öncesi kontrol listesi + panele bağımlı eksiklerin durumu.
---

# ship — Release Kapısı

## Otomatik Kapı (hepsi sıfır hata ile geçmeli)
```
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build appbundle --release --dart-define-from-file=.env   # yayın = AAB
```

## Kod Tarafı Kontroller
- [ ] `kDemoMode == false`
- [ ] `pubspec.yaml` version artırıldı (semver + build no)
- [ ] Yeni koleksiyon eklendiyse rules deploy edildi mi (`firebase deploy --only firestore`)
- [ ] Yeni .arb anahtarlarının EN eşleniği var (gen-l10n hatasız kanıtıdır)
- [ ] `.env`'de gizli anahtar sızıntısı yok (SERVICE_ROLE/ANTHROPIC asla client'ta)

## Panele Bağımlı Eksikler (kod değil — durumunu raporla, sahibi kullanıcı)
- Supabase: Google/Apple provider + reset-password redirect URL
- Google Cloud: OAuth client ID'ler → `.env` `GOOGLE_SERVER_CLIENT_ID`
- RevenueCat: ürünler + `REVENUECAT_API_KEY`
- Play/App Store: upload keystore (`android/key.properties`), store listing
- Firestore: kopya makale `--prune` (functions/scripts/seedArticles.js)
- Supabase service-role anahtarı ROTASYONu (bir kez sızdı)

## Release Gate Matrisi (her satır PASS/FAIL, FAIL = yayın durur)
| Alan | Kontrol |
|---|---|
| Architecture | Açık ADR'sız L-değişiklik yok; Sert Kurallar ihlali yok |
| Security | Client'ta gizli anahtar yok; rules deploy güncel; App Check aktif |
| Error Handling | Yeni dış çağrılar timeout'lu + fallback'li |
| Localization | gen-l10n hatasız; yeni akış EN cihazda anlamlı |
| Responsive/A11y | ui checklist'i son eklenen ekranlarda işaretli |
| Testing | Suite yeşil; para/veri/auth değişiklikleri testli |
| Performance | Bilinen jank raporu yok; AAB boyutu önceki sürümü ~aşmıyor |
| Crash Reporting | Crashlytics release'te açık; test crash'i düştü (ilk yayında) |
| Analytics | Yeni event'ler sözlükte ve konsolda görünüyor |
| Offline | Uçak modu açılış + temel akış nazik davranıyor |
| Docs/Changelog | CHANGELOG güncel; kullanıcıya kalan panel işleri listeli |

## Cihaz QA
docs/release_qa_checklist.md kullanıcıya verilir; kritik teyitler: ilk-giriş
köprüsü, hesap değişimi izolasyonu, uçak modu, koyu mod overlay'leri, EN cihaz.

## Rapor
Geçen kapılar / bekleyen panel işleri / bilinen riskler / sürüm notu taslağı.

## Definition of Done
- [ ] Otomatik kapı + Gate Matrisi tamamı PASS (FAIL'ler gerekçeli raporda)
- [ ] Sürüm artırıldı, changelog yazıldı, decisions.md güncellendi
