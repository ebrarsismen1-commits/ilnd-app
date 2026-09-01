# Mac Olmadan iOS Yayını

Geliştirme makinesi Windows. iOS derlemesi macOS ister ama **yalnız derleme**
ister: geri kalan her şey ya tarayıcıda ya repo dosyasında yapılır.

## Neyin nerede yapıldığı

| İş | Yer | Mac gerekir mi |
|---|---|---|
| Apple Developer üyeliği | developer.apple.com | Hayır |
| Bundle kimliği kaydı (`com.ilnd.ilndApp`) | Apple paneli | Hayır |
| Sertifika ve provisioning profili | Apple paneli veya CI otomatik | Hayır |
| App Store Connect API anahtarı (`.p8`) | App Store Connect | Hayır |
| APNs anahtarı (`.p8`, push için) | Apple paneli | Hayır |
| Uygulama kaydı, TestFlight, metinler, görseller | appstoreconnect.apple.com | Hayır |
| Capability'ler, entitlements, `Info.plist` | **Repo dosyaları** | Hayır |
| `flutter build ipa`, imzalama, yükleme | **Bulut macOS koşucusu** | Evet, kiralık |

Xcode'un yaptığı ayarların çıktısı düz XML ve `project.pbxproj` satırlarıdır.
CI de zaten o dosyaları okur, Xcode arayüzünü değil. Bu yüzden capability
eklemek için Xcode şart değil.

## Adımlar

### 1. Apple Developer Program

99 $/yıl, tarayıcıdan. Bireysel üyelik yeterli. Onay genelde birkaç gün
sürebiliyor, bu yüzden ilk sırada.

Sonrasında Apple panelinde:

- **Identifiers**: `com.ilnd.ilndApp` bundle kimliğini kaydet.
  Push kullanılacaksa aynı ekranda **Push Notifications** yeteneğini işaretle.
- **Keys**: iki ayrı anahtar üretilecek, ikisi de `.p8` ve **bir kez indirilir**:
  - **App Store Connect API key**: CI'ın TestFlight'a yüklemesi için.
    Issuer ID, Key ID ve `.p8` içeriği not edilir.
  - **APNs key**: push için. Firebase Console → Project settings → Cloud
    Messaging → iOS uygulaması altına yüklenir.

`.p8` dosyaları gizli anahtardır: repoya girmez, sohbete yapıştırılmaz, yalnız
CI'ın secret deposuna konur.

### 2. App Store Connect kaydı

appstoreconnect.apple.com üzerinde uygulama kaydı açılır (aynı bundle
kimliği, ad, birincil dil, kategori). TestFlight bu kayıt olmadan çalışmaz.

Metinler `docs/MAGAZA_METINLERI.md`, görseller `store_assets/` içinde hazır
(1024 ikonlar ve 1080x1920 ekran görüntüleri App Store için uygun).

### 3. Bulut macOS koşucusu

Flutter için en az sürtünmeli seçenek **Codemagic**: ücretsiz kademede aylık
500 dakika macOS makinesi, iOS imzalama ve TestFlight yüklemesi yerleşik.
Yapılandırma repo kökünde `codemagic.yaml` dosyasıyla yapılır, yani ayar da
sürüm kontrolünde kalır.

Alternatif: GitHub Actions `macos-latest`. Çalışır ama özel repolarda macOS
dakikaları 10 kat sayılır, yani aynı iş belirgin şekilde pahalıya gelir.

Koşucuya verilecek secret'lar:

- App Store Connect API key (Issuer ID, Key ID, `.p8`)
- İmzalama sertifikası ve profili (Codemagic otomatik üretebiliyor)
- **`.env` içeriği** (aşağıya bak)

### 4. `.env` tuzağı

Bu repoda derleme, gizli yapılandırmayı `--dart-define-from-file=.env`
üzerinden alır. Bayrak unutulursa `AppConfig`'in **tüm alanları boş dizeye
düşer**, derleme yine de başarılı olur ve uygulama çalışma zamanında sessizce
ölür. Web'de tam olarak bu yaşandı (`docs/decisions.md`, 24 Ağustos 2026):
derleme temiz, deploy başarılı, canlıda Supabase hiç kurulmadı.

Yani iOS derleme komutu şu, bayraksızı yanlıştır:

```bash
flutter build ipa --release --dart-define-from-file=.env
```

`.env` repoda değil (`.gitignore`), bu yüzden CI'da secret olarak tutulup
derlemeden önce dosyaya yazılır. Mevcut `release.yml`'in Android tarafında
aynı desen zaten var, oradan kopyalanabilir.

Derleme sonrası doğrulama alışkanlığı web'de kondu, iOS'ta da aynısı geçerli:
üretilen paket içinde beklenen değerlerden birinin geçtiğini kontrol et,
boş yapılandırmayla çıkılmış bir sürümü mağazaya göndermek en pahalı hata.

**Şu an `.env` içinde `REVENUECAT_API_KEY` ve `RECAPTCHA_SITE_KEY` yok.**
Birincisi olmadan paywall her derlemede etkisizdir ve satın alma hiç başlamaz.

### 5. Push için repo tarafı

Push kullanılacaksa şunlar gerekir, üçü de dosya düzenlemesi:

- `ios/Runner/Runner.entitlements` (yok, oluşturulacak): `aps-environment`
  anahtarı, geliştirmede `development`, yayında `production`
- `project.pbxproj` içinde `CODE_SIGN_ENTITLEMENTS` bu dosyaya bağlanır
- `Info.plist` içine `UIBackgroundModes` → `remote-notification`

Dart tarafı (`firebase_messaging`, izin akışı, token'ın hesaba yazılması) ve
gönderim tarafı (zamanlanmış Cloud Function) bunlardan bağımsız yazılabilir
ama **cihaz olmadan doğrulanamaz**: push simülatörde hiç çalışmaz.

### 6. TestFlight

CI'ın ürettiği `.ipa` App Store Connect'e yüklenir, işlenmesi birkaç dakika
sürer, sonra TestFlight'tan kendi cihazına kurarsın. İç test grubunda Apple
incelemesi beklenmez; dış test grubunda kısa bir inceleme vardır.

Gerçek cihazda doğrulanacaklar, çünkü hiçbiri testte yakalanmaz:

- İlk giriş köprüsü (Supabase → Firebase) ve hesap değişiminde veri izolasyonu
- Derin bağlantı dönüşü (Sert Kural #15: Dart, native ve Supabase allowlist'i
  birlikte doğru olmalı, biri eksikse akış sessizce ölür)
- Satın alma akışı (sandbox hesabıyla)
- Bildirim izni ve push teslimi
- Koyu mod, dinamik yazı tipi boyutu, dar cihaz (iPhone SE)

## Sıra

1. Apple Developer üyeliği (onay beklenir, bu yüzden ilk)
2. Bundle kimliği + App Store Connect API anahtarı
3. Codemagic bağlanır, `.env` secret olarak konur, ilk `.ipa` üretilir
4. App Store Connect kaydı, ilk TestFlight derlemesi
5. Cihazda doğrulama listesi
6. Push istenirse: APNs anahtarı, entitlements, Dart ve sunucu tarafı

1 ve 2 tamamlanana kadar iOS'a özgü hiçbir iş ilerleyemez. O sırada
`docs/ios/README.md` içindeki "Apple hesabı gerektirmeyen işler" listesi
paralel yürür.
