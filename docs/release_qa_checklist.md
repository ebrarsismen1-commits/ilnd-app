# ilnd — Release QA Checklist (cihazda manuel)

Her akış release build ile (`flutter run --release --dart-define-from-file=.env`
veya APK yükleyerek) test edilmeli. İdeal matris: 1 küçük Android (düşük RAM) +
1 güncel Android + 1 iPhone. Her maddeye ✅/❌ + not düşün.

## 1. Onboarding (temiz kurulum)
- [ ] Welcome → isim/hedef girişi → first-entry akışı kesintisiz ilerliyor
- [ ] First-entry'de "şimdi değil" ile atlama çalışıyor
- [ ] Onboarding yarıda bırakılıp uygulama kapatılınca kaldığı adımdan devam ediyor (loop yok)
- [ ] Sosyal kanıt rozeti welcome'da görünüyor ya da zarifçe gizli (hata yok)

## 2. Kayıt & Giriş
- [ ] E-posta kayıt: geçersiz e-posta/kısa şifre/uyuşmayan şifre alan-bazlı kırmızı + doğru mesaj
- [ ] Kayıt sonrası first-entry ekranına düşüyor; günlük YAZILABİLİYOR (ilk-giriş köprü düzeltmesinin cihaz teyidi — kritik)
- [ ] Yanlış şifre ile giriş: "E-posta veya şifre hatalı" (İngilizce cihazda İngilizcesi)
- [ ] Şifremi unuttum: e-posta geliyor, linkteki sayfada şifre değişiyor, yeni şifreyle giriş oluyor
- [ ] Google ile giriş (panel kurulumu sonrası): hesap seçici → giriş; seçiciyi kapatınca hata YOK
- [ ] Apple ile giriş (iOS, kurulum sonrası): aynı davranış
- [ ] Çıkış yap → login ekranı; geri tuşu ile içeri sızılamıyor

## 3. Hesap değişimi (Phase 3 düzeltmelerinin cihaz teyidi — kritik)
- [ ] A hesabıyla sohbet et + günlük yaz → çıkış → B hesabıyla gir:
  - [ ] Sohbet geçmişi BOŞ başlıyor
  - [ ] ILND, A'nın adını/hedeflerini/notlarını BİLMİYOR
  - [ ] Journal/Takip A'nın verilerini GÖSTERMİYOR
- [ ] A'ya geri dön: hafızası ve verileri yerinde

## 4. Günlük & Mood & Sohbet
- [ ] Mood seçimi: seçim animasyonu → sohbete akış; ILND cevap veriyor
- [ ] Uçak modunda mesaj gönder: karakter-içi fallback/nazik hata (ham exception YOK), sohbet kilitlenmiyor
- [ ] Günlük yaz → kaydet → listede görünüyor; ILND karşılığı geliyor
- [ ] Ücretsiz haftalık sohbet limiti dolunca paywall açılıyor (bir kez, tekrar tekrar değil)

## 5. Yemek ekle / Takip / Alışkanlık / Su
- [ ] Kamera + galeri izin akışları; iptalde hata yok
- [ ] Fotoğraf analizi: sonuç + makrolar + ILND yorumu; kaydet → Takip'te görünüyor
- [ ] Uçakta analiz: "internet yok" mesajı; ekran "analiz ediliyor"da ASILI KALMIYOR (Phase 5 teyidi)
- [ ] Alışkanlık ekle/tamamla; su ekle; Takip ekranı doğru topluyor
- [ ] Streak: iki farklı günde aktivite → sayı artıyor

## 6. Profil / Referral / Vibe Card / Paywall
- [ ] İstatistikler doluyor; rozetler mantıklı
- [ ] Referral kodu görünüyor, kopyala/paylaş çalışıyor; kod kullanma akışı
- [ ] Vibe card üretiliyor ve paylaşılıyor
- [ ] Paywall (RevenueCat kurulumu sonrası): sandbox satın alma + restore
- [ ] Gizlilik/Şartlar sayfaları açılıyor (girişsiz de — kayıt ekranındaki linklerden)
- [ ] Hesabı sil: onay → siliniyor → aynı e-postayla tekrar kayıt olunabiliyor

## 7. Tema / Dil / Platform
- [ ] Koyu mod: TÜM ekranlar + dialog/bottom-sheet'ler koyu (Phase 7 teyidi); geçiş anında sıçrama yok
- [ ] Cihaz dili İngilizce: tüm arayüz İngilizce, ILND İngilizce cevap veriyor, yemek adı İngilizce
- [ ] Küçük ekranda (SE / 320dp) taşma yok; klavye açıkken composer/editör görünür
- [ ] Ekran döndürme (varsa) / sistem geri jesti tutarlı

## 8. Yaşam döngüsü & Ağ
- [ ] Uygulamayı öldür → aç: oturum duruyor, direkt Bugün'e düşüyor (splash → home)
- [ ] Uçak modunda aç: başlatma hatası ekranı YOK (Firebase cache); sadece ağ isteyen yerler nazik hata
- [ ] Uçaktan çık: journal/takip kendini topluyor (yeniden girişte)
- [ ] Arka plana at → 10 dk sonra dön: donma/beyaz ekran yok

## 9. Analytics / Crashlytics (yayın öncesi bir kez)
- [ ] Firebase konsolunda app_open + onboarding event'leri düşüyor mu
- [ ] Release build'de bilerek bir test crash'i (geçici buton) Crashlytics'e düşüyor mu

---
Otomatik kapılar (her PR'da CI zaten koşuyor): format ✅ analyze ✅ 54 test ✅ release APK ✅
