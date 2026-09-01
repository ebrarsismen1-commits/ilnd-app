# iOS Yayını

Dağıtım hedefi **yalnız iOS** (karar: 31 Ağustos 2026). Google Play iptal
edildi ama silinmedi; Play'e ait her şeyin envanteri
`docs/arsiv-google-play/README.md` dosyasında duruyor ve geri dönüş mümkün.

Bu klasör iOS yayınıyla ilgili çalışmanın evi. Ürün, tasarım ve mimari
belgeleri yerinde kalmaya devam ediyor (`docs/PROJECT_PRINCIPLES.md`,
`docs/adr/`, `docs/tr/`).

## Belgeler

| Dosya | İçerik |
|---|---|
| `YAYIN_HATTI.md` | Mac olmadan iOS derleme ve TestFlight yayını |

Mağaza gönderim kontrol listesinin App Store bölümü hâlâ
`docs/tr/UYGULAMA_MAGAZASI_KONTROL.md` içinde; mağaza metinleri
`docs/MAGAZA_METINLERI.md`, görseller `store_assets/`.

## Şu an hazır olanlar

- `ios/Runner/GoogleService-Info.plist` **gerçek ve doğru**
  (proje `ilnd-app-8dcbd`, bundle `com.ilnd.ilndApp`). Eksik olan
  Android tarafındaki `google-services.json` idi, o da artık önemsiz.
- Bundle kimliği: `com.ilnd.ilndApp`
- Derin bağlantı şeması: `com.ilnd.app` (Sert Kural #15 gereği Dart, native
  ve Supabase panelinde birlikte tutulur; tutarlılık
  `test/features/auth/deep_link_config_test.dart` ile kilitli)
- Kod tabanı: `flutter analyze` temiz, 442 test yeşil
- İkon ve ekran görüntüleri App Store boyutlarında hazır (`store_assets/`)
- Tipografi: Noto Serif (başlık) + DM Sans (gövde) + DM Mono (sayı), üçü de
  pakete gömülü. Çalışma anında font indirilmiyor, yani ağsız ilk açılışta da
  uygulama doğru görünüyor

## Şu an eksik olanlar

| Eksik | Etkisi | Kim yapar |
|---|---|---|
| Apple Developer Program üyeliği | Hiçbir iOS dağıtımı mümkün değil | Kullanıcı (99 $/yıl, tarayıcı) |
| Bulut macOS koşucusu (Codemagic vb.) | `.ipa` üretilemez | Kurulumu birlikte, hesap kullanıcıda |
| `ios/Runner/Runner.entitlements` | Push bildirimi çalışmaz | Repo dosyası, yazılabilir |
| `.env` içinde `REVENUECAT_API_KEY` | **Paywall her derlemede etkisiz**, satın alma hiç başlamaz | Kullanıcı (RevenueCat paneli) — *yayın öncesine bırakıldı, 31 Ağustos kararı* |
| APNs `.p8` anahtarı, Firebase'e yüklü | FCM gönderemez | Kullanıcı (Apple paneli) |
| Test için fiziksel iPhone | Push simülatörde hiç çalışmaz | Kullanıcı |

`REVENUECAT_API_KEY` eksikliği en sessiz olanı: `AppConfig.revenueCatApiKey`
boş dizeye düşüyor, `RevenueCatService.initialize` erkenden çıkıyor ve paywall
hiçbir hata vermeden hiçbir şey yapmıyor. iOS-only bir üründe gelirin tek
kapısı burası olduğu için yayın öncesi kapatılması şart. Aynı sınıf hata web
deploy'unda bir kez yaşandı (`docs/decisions.md`, 24 Ağustos 2026).

## Yol haritası

**Apple hesabı gerektirmeyen işler** (bugün yapılabilir, hepsi testlenebilir):

1. Analitik boşlukları: yemek analizi ve paywall olayları
   (`docs/tr/ANALITIK_SOZLUGU.md` "Bilinen boşluklar")
2. RevenueCat seam'i ve paywall sonuç yollarının testleri
3. Topluluk kapasite kontrolü (`capacity` alanı hiçbir yerde uygulanmıyor)
4. Analitik sözlüğü bekçisi testi, `trio_*_done` yön hatası

**Apple hesabı açıldıktan sonra, tek fazda:**

1. `YAYIN_HATTI.md` adımları: sertifika, App Store Connect kaydı, CI
2. `Runner.entitlements` + `UIBackgroundModes` + izin metinleri
3. FCM: Dart tarafı, token'ın hesaba yazılması, zamanlanmış Cloud Function
4. İlk TestFlight derlemesi ve cihazda doğrulama
