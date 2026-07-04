# Katkı Kılavuzu

## Dallanma Stratejisi

```
main          ← yalnızca üretim yayınları (etiketlenmiş)
develop       ← entegrasyon dalı
feature/*     ← yeni özellikler
fix/*         ← hata düzeltmeleri
chore/*       ← kullanıcıya görünmeyen değişiklikler
docs/*        ← yalnızca belgeleme
```

Tüm çalışmalar `develop` dalından ayrılır. Yalnızca yayın commit'leri `main`'e gider.

---

## Commit Kuralı

ilnd, [Conventional Commits](https://www.conventionalcommits.org/) kullanır:

```
<tür>(<kapsam>): <konu>

[isteğe bağlı gövde]

[isteğe bağlı alt bilgi]
```

**Türler:**

| Tür | Ne Zaman Kullanılır |
|-----|-------------------|
| `feat` | Yeni kullanıcıya yönelik özellik |
| `fix` | Hata düzeltmesi |
| `refactor` | Davranış değişikliği olmayan kod yeniden yapılandırması |
| `docs` | Yalnızca belgeleme |
| `test` | Test eklemeleri veya düzeltmeleri |
| `chore` | Derleme sistemi, bağımlılıklar, CI |
| `perf` | Performans iyileştirmesi |
| `style` | Biçimlendirme, mantık değişikliği yok |

**Örnekler:**
```
feat(auth): şifremi unuttum ekranı ekle
fix(habits): toggleCompletion'ı Firestore transaction'ına sar
refactor(ui): kayıt ekranını paletProvider'a geçir
docs(api): redeemReferralCode istek/yanıt örnekleri ekle
```

---

## Pull Request Süreci

1. `develop` dalından dal aç
2. Conventional commit'lerle değişiklikleri yap
3. Test paketini yerel olarak çalıştır:
   ```bash
   flutter analyze
   flutter test
   dart format --set-exit-if-changed lib test
   cd functions && npm test
   ```
4. `develop` hedefli PR aç
5. PR açıklaması şunları içermeli:
   - Ne değişti ve neden
   - Değişikliği nasıl test ederiz
   - UI değişiklikleri için ekran görüntüleri
6. CI yeşil olmalı, birleştirmeden önce
7. En az bir onaylayıcı inceleme gerekli

---

## Kod Standartları

### Dart / Flutter

- `flutter_lints` kural setini takip et (CI tarafından zorunlu tutulur)
- `print()` kullanma — hata ayıklama kodunda `debugPrint()` kullan
- Kontrol akışında her zaman süslü parantez kullan
- Mümkün olan her yerde `const` yapıcıları tercih et
- Sabit kodlanmış renk değerleri kullanma — `paletteProvider` üzerinden `AppPalette` kullan
- Kullanıcılara görünen diziler için sabit kodlanmış string kullanma — `AppLocalizations` kullan
- Riverpod: build metodunda `ref.watch`, callback'lerde yalnızca `ref.read`

### JavaScript (Cloud Functions)

- Mevcut `functions/index.js` ile tutarlı ES modules stili
- Tüm async fonksiyonlar `async/await` kullanır
- Tüm HTTP uç noktaları herhangi bir iş mantığından önce kimlik doğrulamayı doğrular
- Birden fazla belge içeren Firestore mutasyonları `runTransaction` kullanır
- Kodda gizli anahtar yok — `defineSecret()` ve Firebase Secret Manager kullan

---

## Yeni Cloud Function Ekleme

1. `functions/index.js` dosyasında tanımla
2. Hassas veri işliyorsa App Check zorunluluğu ekle
3. `functions/test/<fonksiyonAdi>.test.js` konumuna test dosyası ekle
4. [`API.md`](API.md) belgesini istek/yanıt belgeleriyle güncelle
5. İstemci tarafı URL gerekiyorsa `lib/core/services/app_config.dart` dosyasına ekle

---

## Yeni Ekran Ekleme

1. `lib/features/<özellik>/<özellik>_screen.dart` oluştur
2. `ConsumerWidget` genişlet
3. Tüm renkler için `ref.watch(paletteProvider)` kullan
4. Herhangi bir metin veya doğrulayıcı için `AppLocalizations.of(context)!` ilet
5. Rotayı `lib/core/router/app_router.dart` dosyasına ekle
6. Etkileşimli öğelere erişilebilirlik semantiği ekle (minimum 44 piksel)
7. En az bir widget testi yaz

---

## Yayın Süreci

1. Tüm özellikler ve düzeltmeler `develop` dalına birleştirildi
2. Yayın dalı oluştur: `release/v1.x.x`
3. `pubspec.yaml`'daki sürümü güncelle
4. `CHANGELOG.md`'yi güncelle
5. CI yeşil olmalı
6. Fiziksel cihazda smoke test
7. `main` dalına birleştir
8. Etiketle: `git tag v1.x.x && git push origin v1.x.x`
9. GitHub Actions yayın iş akışı AAB'yi derler ve imzalar
10. AAB'yi Google Play'e yükle + iOS IPA'yı arşivle

---

## İlgili Belgeler

- [GELISTIRME.md](GELISTIRME.md) — yerel geliştirme iş akışı
- [TEST.md](TEST.md) — test kalıpları
- [MIMARI.md](MIMARI.md) — sistem tasarımı bağlamı
