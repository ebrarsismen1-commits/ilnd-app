# Google Play Arşivi

**Durum: parkedildi, iptal edilmedi.** 31 Ağustos 2026'da dağıtım hedefi
yalnız iOS olarak belirlendi. Bu klasör, Play'e dönüldüğünde hiçbir şeyin
sıfırdan yapılmaması için var.

**Buradaki hiçbir şey silinmemeli.** Play tarafı "ölü kod" gibi görünebilir
ama yeniden canlandırılacak, ve yeniden üretmek saatler alır.

## Nerede ne var

Çoğu dosya yerinde bırakıldı, çünkü ya iki mağaza için ortak ya da taşınması
derlemeyi kırar. Bu tablo neyin nerede olduğunu ve neden durduğunu söyler.

| Ne | Nerede | Neden yerinde | Play'e dönünce |
|---|---|---|---|
| Android proje ağacı | `android/` (31 MB) | Flutter tek kod tabanı; taşımak derlemeyi kırar | Dokunmaya gerek yok, çalışır |
| İmzalı AAB iş akışı | `.github/workflows/release.yml` | Çalışır durumda, yalnız tetiklenmiyor | Aynen kullanılır |
| Play ikonları (512x512) | `store_assets/icon/icon_*_512.png` | App Store'un 1024'lükleriyle aynı klasörde, ayırmak anlamsız | Hazır |
| Öne çıkan grafik (1024x500) | **bu klasör**, `feature_graphic_1024x500.png` | Yalnız Play kullanır, App Store'da karşılığı yok | Hazır |
| Ekran görüntüleri | `store_assets/screenshots_tr`, `screenshots_en` | 1080x1920, iki mağaza için de uygun | Hazır |
| Mağaza metinleri | `docs/MAGAZA_METINLERI.md` | Play ve App Store bölümleri birlikte | Play bölümü hazır |
| Gönderim kontrol listesi | `docs/tr/UYGULAMA_MAGAZASI_KONTROL.md` | "Google Play" bölümü dosyanın başında duruyor | Liste hazır |
| Android Firebase yapılandırması | `android/app/google-services.json` | `.gitignore`'da, bilerek repoda değil | Yeniden indirilir |

## Play'e dönüldüğünde yapılacaklar

1. **`GOOGLE_SERVICES_JSON_BASE64` GitHub secret'ı eklenir.**
   Değer: `base64 -w0 android/app/google-services.json` çıktısı.
   Yeri: repo Settings → Secrets and variables → Actions.
   Bu secret olmadan `release.yml` **bilerek erken düşer** ve `.aab` hiç
   üretilmez. `ci.yml` etkilenmez, orada yer tutucu devreye girer
   (`android/app/google-services.ci-placeholder.json`).
2. **İmzalama secret'ları** doğrulanır (upload keystore, `key.properties`).
3. Play Console'da uygulama kaydı, IARC içerik derecelendirme anketi ve
   Veri Güvenliği bölümü doldurulur (kontrol listesindeki adımlar).
4. Play Geliştirici hesabı: 25 $ tek seferlik.

## Neden parkedildi

Kullanıcı kararı. Tek bir mağazaya odaklanmak, iki mağazanın inceleme
süreçlerini, iki ayrı imzalama zincirini ve iki ayrı test cihazı ihtiyacını
aynı anda taşımaktan ucuz. Karar geri alınabilir ve kod tarafında hiçbir şey
kaybedilmedi: aynı Flutter projesi her iki platformu da üretmeye devam ediyor.

İlgili: `docs/ios/README.md`, `docs/decisions.md`
