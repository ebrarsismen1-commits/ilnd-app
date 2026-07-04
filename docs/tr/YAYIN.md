# Yayın Kılavuzu

## Sürüm Numaralandırma

ilnd, [Semantic Versioning](https://semver.org/) kullanır:

- `MAJOR.MINOR.PATCH+BUILD`
- **MAJOR:** Kullanıcı verisi veya kimlik doğrulama akışında kırıcı değişiklikler
- **MINOR:** Yeni özellikler (geriye dönük uyumlu)
- **PATCH:** Hata düzeltmeleri
- **BUILD:** Mağaza gönderimleri için monoton artan tamsayı

Mevcut sürüm: `1.0.0+1` (`pubspec.yaml` dosyasında)

---

## Yayın Türleri

| Tür | Etiket Biçimi | Örnek |
|-----|--------------|-------|
| Yayın Adayı | `v{sürüm}-rc{n}` | `v1.0.0-rc1` |
| Üretim | `v{sürüm}` | `v1.0.0` |
| Hızlı Düzeltme | `v{sürüm}` (yama artışı) | `v1.0.1` |

---

## Yayın Kontrol Listesi

### 1. Kod Dondurma

```bash
git checkout develop
git pull origin develop
git checkout -b release/v1.x.x
```

### 2. Sürüm Artışı

`pubspec.yaml` dosyasını düzenle:
```yaml
version: 1.x.x+{derleme_numarasi}
```

Derleme numarası son gönderimden daha yüksek olmalı.

### 3. Changelog

`CHANGELOG.md` dosyasını güncelle:
- Yayınlanmamış öğeleri yeni sürüm başlığı altına taşı
- Tarih ekle
- Bilinen Sınırlamalar bölümünü gözden geçir

### 4. Son Kontroller

```bash
flutter analyze
flutter test
dart format --set-exit-if-changed lib test
cd functions && npm test
```

### 5. Smoke Test

Fiziksel cihaza yayın derlemesi yükle. [DAGITIM.md](DAGITIM.md) dosyasındaki smoke test kontrol listesini tamamla.

### 6. Commit ve Etiket

```bash
git add pubspec.yaml CHANGELOG.md
git commit -m "chore(release): v1.x.x sürümüne yükselt"
git tag v1.x.x
git push origin release/v1.x.x
git push origin v1.x.x
```

Etiketi göndermek GitHub Actions yayın iş akışını tetikler.

### 7. Birleştir

```bash
git checkout main && git merge release/v1.x.x
git checkout develop && git merge release/v1.x.x
git branch -d release/v1.x.x
```

---

## GitHub Actions Yayın İş Akışı

[`.github/workflows/release.yml`](../../.github/workflows/release.yml) dosyasında tanımlanmıştır.

Tetikleyici: `v*.*.*` etiketleri

Adımlar:
1. Tüm imzalama sırlarının yapılandırıldığını kontrol et
2. `ANDROID_KEYSTORE_BASE64` sırrını `.jks` dosyasına çöz
3. İmzalı yayın AAB derle: `flutter build appbundle --release`
4. Keystore dosyasını çalışma ortamından sil
5. İmzalı AAB'yi GitHub Actions eseri olarak yükle

Eseri Actions çalıştırmasından indir ve Google Play Console → İç Test'e yükle.

---

## Android Yayını

### İmzalama

Yayın iş akışı AAB'yi otomatik olarak imzalar. Yerel yayın derlemeleri için `android/key.properties` mevcut olmalı. Bkz. [`android/KEYSTORE.md`](../../android/KEYSTORE.md).

### Play Store İzleme Kanalları

| Kanal | Amaç |
|-------|------|
| İç Test | Ekip doğrulaması |
| Kapalı Test | Beta kullanıcıları |
| Açık Test | Katılım tabanlı halka açık beta |
| Üretim | Tam yayın (%10 → %50 → %100 ile başla) |

---

## iOS Yayını

### Derleme

```bash
# Xcode: Product → Archive
```

Arşiv → Xcode Organizer → Uygulamayı Dağıt → App Store Connect → Yükle

### TestFlight

Yüklemeden sonra:
1. TestFlight derleme işleme 15-30 dakika sürer
2. Dahili test grubuna derleme ekle
3. Harici test kullanıcılarıyla TestFlight bağlantısını paylaş

---

## Hızlı Düzeltme Süreci

Kritik üretim hataları için:

```bash
git checkout main
git checkout -b hotfix/v1.x.y
# Düzeltmeyi yap
git commit -m "fix(<kapsam>): <açıklama>"
git checkout main && git merge hotfix/v1.x.y
git checkout develop && git merge hotfix/v1.x.y
git tag v1.x.y
git push origin v1.x.y
git branch -d hotfix/v1.x.y
```

---

## İlgili Belgeler

- [DAGITIM.md](DAGITIM.md) — ön dağıtım ve smoke test
- [UYGULAMA_MAGAZASI_KONTROL.md](UYGULAMA_MAGAZASI_KONTROL.md) — mağaza gönderim kontrol listesi
