# Uygulama Mağazası Gönderim Kontrol Listesi

## Google Play

### Hesap ve Kurulum
- [ ] Google Play Geliştirici hesabı aktif (25 $ tek seferlik ücret)
- [ ] Play Console'da `com.ilnd.ilnd_app` paket adıyla uygulama oluşturuldu
- [ ] Uygulama içerik derecelendirmesi anketi tamamlandı (IARC)
- [ ] Uygulama kategorisi ayarlandı: Sağlık ve Fitness

### Derleme
- [ ] GitHub Actions yayın iş akışı tarafından imzalı yayın AAB üretildi
- [ ] Sürüm kodu son gönderimden yüksek
- [ ] `android/app/build.gradle.kts` dosyasında `minSdkVersion 26` (Android 8.0) onaylandı
- [ ] Uygulama boyutu incelendi (hedef < 100 MB temel APK)

### Mağaza Girişi (üretim yayını öncesinde gerekli)
- [ ] Uygulama adı: "ilnd – iyi hisset, iyi yaşa" (50 karakter sınırı)
- [ ] Kısa açıklama (80 karakter) — Türkçe ve İngilizce
- [ ] Tam açıklama (4000 karakter) — Türkçe ve İngilizce
- [ ] Uygulama simgesi: 512×512 PNG, şeffaflık yok
- [ ] Öne çıkan grafik: 1024×500 PNG veya JPG
- [ ] Ekran görüntüleri: cihaz türü başına minimum 2, maksimum 8:
  - [ ] Telefon (1080×1920 veya benzer)
  - [ ] 7 inç tablet (isteğe bağlı)
  - [ ] 10 inç tablet (isteğe bağlı)

### Veri Güvenliği (Google Play gizlilik bölümü)
- [ ] Toplanan veriler beyan edildi: e-posta adresi (gerekli), uygulama etkinliği
- [ ] Üçüncü taraflarla veri paylaşımı beyan edildi: Firebase, Supabase, Anthropic, RevenueCat
- [ ] Transit veri şifreleme: Evet
- [ ] Kullanıcılar silme talebinde bulunabilir: Evet (uygulama içi hesap silme + e-posta)

### Politika Uyumluluğu
- [ ] Gizlilik Politikası URL'si mağaza girişine eklendi
- [ ] Gizlilik Politikası URL'si girişsiz erişilebilir
- [ ] Açıklama veya ekran görüntülerinde yanıltıcı sağlık iddiası yok
- [ ] Uygulama 13 yaşın altındaki kullanıcılardan veri toplamıyor (COPPA uyumluluğu onaylandı)

---

## Apple App Store

### Hesap ve Kurulum
- [ ] Apple Developer Program kaydı (yıllık 99 $)
- [ ] App Store Connect'te `com.ilnd.ilndApp` Bundle ID ile uygulama oluşturuldu
- [ ] Uygulama kategorisi: Sağlık ve Fitness (birincil), Yaşam Tarzı (ikincil)

### Derleme
- [ ] Distribution sertifikasıyla Xcode'dan IPA arşivlendi
- [ ] Sürüm ve derleme numarası `pubspec.yaml` ile eşleşiyor
- [ ] Minimum iOS sürümü: 16.0
- [ ] Özel API kullanımı yok

### Mağaza Girişi
- [ ] Uygulama adı: "ilnd" (30 karakter sınırı)
- [ ] Alt başlık: "iyi hisset, iyi yaşa" (30 karakter)
- [ ] Açıklama (4000 karakter) — Türkçe ve İngilizce
- [ ] Tanıtım metni (170 karakter, yeni derleme gerektirmeden değiştirilebilir)
- [ ] Anahtar kelimeler (100 karakter) — wellness, günlük, journal, ai, sağlık
- [ ] Uygulama simgesi: 1024×1024 PNG (şeffaflık yok)
- [ ] Cihaz boyutuna göre ekran görüntüleri:
  - [ ] 6,7 inç iPhone (iPhone 15 Pro Max) — zorunlu
  - [ ] 6,5 inç iPhone (iPhone 14 Plus) — zorunlu
  - [ ] 5,5 inç iPhone (iPhone 8 Plus) — zorunlu
  - [ ] 12,9 inç iPad Pro — iPad destekleniyorsa zorunlu
- [ ] Destek URL'si: girişsiz yüklenen aktif URL
- [ ] Gizlilik Politikası URL'si: girişsiz yüklenen aktif URL

### Uygulama Gizliliği (zorunlu)
- [ ] Toplanan veriler kategoriye göre beyan edildi:
  - [ ] İletişim bilgisi: e-posta adresi
  - [ ] Kullanıcı içeriği: günlük girişleri, fotoğraflar (yiyecek)
  - [ ] Kullanım verisi: uygulama etkinliği (Firebase Analytics)
  - [ ] Tanılama: çökme verileri (Crashlytics)
- [ ] Kimliğe bağlı veriler: e-posta adresi kullanıcı hesabına bağlı
- [ ] Üçüncü taraf reklamcılık için kullanılan veriler: Hayır
- [ ] ATT kararı: günlük ve AI konuşma verileri birinci taraf; uygulama içi izleme olmadığını mağaza gönderimi öncesinde onayla

### Kılavuz Uyumluluğu
- [ ] 4.2 — Uygulama yeterli benzersiz işlevselliğe sahip
- [ ] 5.1.1 — Gizlilik Politikası mevcut ve doğru
- [ ] 5.1.1(v) — Uygulama içi hesap silme mevcut ✓ (deleteAccount uygulandı)
- [ ] 3.1.1 — Uygulama içi satın almalar Apple IAP kullanıyor ✓ (RevenueCat + Apple IAP)
- [ ] 2.1 — İnceleme cihazında çökme yok (TestFlight ile doğrulandı)
- [ ] Sağlık verisi: HealthKit erişilmiyor (gönderim öncesinde onaylandı)

### TestFlight Doğrulaması
- [ ] Dahili test kullanıcıları: tüm ekranlar çökmeden gezildi
- [ ] Katılım uçtan uca tamamlandı
- [ ] AI sohbet çalışıyor (App Check + anthropicProxy uçtan uca)
- [ ] Davet akışı çalışıyor
- [ ] Uygulama içi satın alma tamamlanıyor (sandbox)
- [ ] Hesap silme uçtan uca çalışıyor
- [ ] Gizlilik Politikası ve Kullanım Şartları girişsiz erişilebilir
- [ ] Koyu mod geçişi uygulama genelinde çalışıyor
- [ ] Çevrimdışı mod: günlük girişleri önbellekten yükleniyor

---

## Her İki Mağaza — Henüz Oluşturulmamış Gerekli Materyaller

Kod tabanında **mevcut olmayan** ve gönderim öncesinde oluşturulması gereken materyaller:

| Materyal | Durum | Notlar |
|----------|-------|--------|
| Uygulama simgesi (1024×1024) | ❌ Oluşturulmadı | `#8B5CF6` marka vurgu rengiyle eşleşmeli |
| Öne çıkan grafik (Google Play 1024×500) | ❌ Oluşturulmadı | |
| Telefon ekran görüntüleri (5-8 mağaza başına) | ❌ Oluşturulmadı | Temel akışları göster: günlük, sohbet, vibe card |
| Tablet ekran görüntüleri | ❌ Oluşturulmadı | iPad / Google Play tablet için gerekli |
| Uygulama önizleme videosu | ❌ İsteğe bağlı | 15-30 saniye, sessiz |
| Kısa mağaza açıklaması (80/170 karakter) | ❌ Yazılmadı | |
| Tam mağaza açıklaması | ❌ Yazılmadı | AI, gizlilik, Gen-Z sesini vurgula |
| v1.0 için yayın notları | ❌ Yazılmadı | |

---

## İlgili Belgeler

- [DAGITIM.md](DAGITIM.md) — smoke test ve yayın
- [YAYIN.md](YAYIN.md) — yayın süreci
- [GUVENLIK.md](GUVENLIK.md) — gizlilik ve veri işleme
