# Dağıtım Kılavuzu

## Yayın Adayı Doğrulama Kapıları

`v1.0.0` etiketlenmeden önce aşağıdakilerin tamamı geçmeli:

- [ ] TestFlight derlemesi en az bir iPhone'da doğrulandı
- [ ] Google Play İç Test derlemesi en az bir Android cihazda doğrulandı
- [ ] Yayın commit'inde CI pipeline yeşil (analiz, test, derleme adımları)
- [ ] Smoke test kontrol listesi tamamlandı (aşağıya bkz.)
- [ ] Firebase App Check üretimde çalışıyor (debug sağlayıcı değil)
- [ ] Crashlytics olayları alıyor (TestFlight derlemesinde zorunlu çöküş ile doğrula)
- [ ] RevenueCat satın alma akışı TestFlight'ta uçtan uca doğrulandı
- [ ] `seedArticles` betiği üretim Firestore'a karşı çalıştırıldı

---

## Ön Koşullar

### Android

1. Yükleme anahtarlığı oluştur — bkz. [`android/KEYSTORE.md`](../../android/KEYSTORE.md)
2. GitHub depo sırlarını ayarla:
   - `ANDROID_KEYSTORE_BASE64`
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`
   - `ANDROID_STORE_PASSWORD`
3. `v1.0.0-rc1` etiketi gönder — yayın iş akışı imzalı `.aab` üretir

```bash
git tag v1.0.0-rc1
git push origin v1.0.0-rc1
```

### iOS

1. Apple Geliştirici portalında `com.ilnd.ilndApp` Uygulama Kimliği oluştur
2. Dağıtım sertifikası + provisioning profili oluştur
3. Xcode'da `ios/Runner.xcworkspace` dosyasını aç
4. Team ve Signing'i dağıtım profiline ayarla
5. `Product → Archive`
6. Xcode Organizer veya Transporter aracılığıyla App Store Connect'e yükle

### Firebase

```bash
# Cloud Functions dağıt
firebase deploy --only functions

# Firestore kuralları + dizinleri dağıt
firebase deploy --only firestore

# Gizli anahtarları ayarla (yalnızca ilk kez)
firebase functions:secrets:set ANTHROPIC_API_KEY
firebase functions:secrets:set SUPABASE_SERVICE_ROLE_KEY
```

### İçerik

```bash
cd functions
npm install
npm run seed:articles
```

---

## Ortam Kurulumu

`.env.example` dosyasını `.env` olarak kopyala ve doldur:

```ini
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
FIREBASE_API_KEY=AIzaSy...
FIREBASE_AUTH_DOMAIN=ilnd-app-8dcbd.firebaseapp.com
FIREBASE_PROJECT_ID=ilnd-app-8dcbd
FIREBASE_STORAGE_BUCKET=ilnd-app-8dcbd.appspot.com
FIREBASE_MESSAGING_SENDER_ID=...
FIREBASE_APP_ID=...
REVENUECAT_API_KEY=appl_...
AUTH_BRIDGE_URL=https://<bölge>-ilnd-app-8dcbd.cloudfunctions.net/mintFirebaseToken
```

---

## Smoke Test Kontrol Listesi

Temiz bir cihaza yayın derlemesi yükledikten sonra:

- [ ] Uygulama çökmeden açılıyor
- [ ] Karşılama ekranı yükleniyor; "başla" düğmesi hızlı kuruluma yönlendiriyor
- [ ] Kayıt, Supabase hesabı oluşturuyor ve davet kodu atıyor
- [ ] Mevcut hesap için giriş çalışıyor
- [ ] İlk günlük girişi ILND AI yanıtını tetikliyor
- [ ] Ana ekran ruh hali kontrolünü, günün makalesini ve günlük niyeti gösteriyor
- [ ] ILND ile sohbet yanıt veriyor (`anthropicProxy` + App Check uçtan uca)
- [ ] Yiyecek fotoğraf analizi çalışıyor
- [ ] Davet kodu kopyalama ve paylaşma çalışıyor
- [ ] Yeni kullanıcı olarak geçerli davet kodu girmek her iki tarafı ödüllendiriyor
- [ ] Premium paywall mesaj limitinden sonra görünüyor
- [ ] RevenueCat satın alma akışı tamamlanıyor (sandbox hesabı kullan)
- [ ] Satın alımları geri yükleme çalışıyor
- [ ] Gizlilik Politikası ve Kullanım Şartları profil ayarlarından yükleniyor
- [ ] Hesap silme tüm verileri siliyor ve giriş ekranına dönüyor
- [ ] Koyu mod geçişi uygulama genelinde temayı değiştiriyor
- [ ] Uygulama çevrimdışı çalışıyor (günlük girişleri görünüyor, makaleler `kArticles`'a geri dönüyor)

---

## Geri Alma Kontrol Listesi

Bir üretim sorunu anında geri almayı gerektirirse:

1. **Flutter uygulaması:** Play Console / App Store Connect'te önceki yayına geri dön
2. **Cloud Functions:** Önceki üretim commit'inden `firebase deploy --only functions`
3. **Firestore kuralları:** Önceki commit'ten `firebase deploy --only firestore`
4. **Firestore verisi:** v1.0'da şema migrasyonu yok — geri alma güvenli
5. **Anthropic API anahtarı rotasyonu:** Proxy uç noktası düzgün çalışmıyorsa, uygulamayı yeniden dağıtmadan anahtarı döndür:
   ```bash
   firebase functions:secrets:set ANTHROPIC_API_KEY
   ```
6. **İçerik:** `content/articles.json`'ı düzelt ve yeniden çalıştır:
   ```bash
   npm run seed:articles -- --prune
   ```

---

## Yayın Sonrası İzleme

İlk 24 saat içinde, ardından ilk hafta boyunca günlük kontrol:

### Crashlytics
- [ ] Oturumların %0,1'inin altında çökme oranı
- [ ] `main()` başlatma hatası yok
- [ ] `AuthNotifier`'dan kritik olmayan hata yok

### Firebase Maliyetleri
- [ ] Firestore okuma/yazma sayısı beklenen aralıkta
- [ ] Cloud Function çağrı sayısı beklenen kullanım modeliyle eşleşiyor
- [ ] `anthropicProxy` günlük kotaları beklenen oranda dolduruluyor

### RevenueCat
- [ ] Abonelik olayları RevenueCat panosunda akıyor
- [ ] Başarısız satın alma olayı artışı yok
- [ ] Hak verme/iptal döngüsü çalışıyor

### Analitik
- [ ] `app_open` olayları akıyor
- [ ] Katılım olayları yeni yüklemelerde mevcut
- [ ] `streak_extended` ve `streak_broken` olayları görünüyor

---

## İlgili Belgeler

- [KURULUM.md](KURULUM.md) — yerel kurulum
- [FIREBASE.md](FIREBASE.md) — Firebase servis yapılandırması
- [GUVENLIK.md](GUVENLIK.md) — gizli anahtarlar ve App Check
- [UYGULAMA_MAGAZASI_KONTROL.md](UYGULAMA_MAGAZASI_KONTROL.md) — mağaza gönderim kontrol listesi
