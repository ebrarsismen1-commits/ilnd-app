# Değişiklik Günlüğü

Kök [`CHANGELOG.md`](../../CHANGELOG.md) dosyasının bu dizindeki kopyasıdır.
Tüm değişiklikler [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) formatında belgelenmektedir.

---

## [Yayınlanmadı] — v1.0.0-rc1

Bu yayın adayı, ilnd'nin ilk üretime hazır derlemesini temsil eder.
Henüz TestFlight veya Google Play İç Test aracılığıyla dağıtılmamıştır.
`v1.0.0` etiketi yalnızca harici doğrulama geçtikten sonra kesilecektir.

### Güvenlik

- **[KRİTİK DÜZELTME]** Firestore `user_growth` koleksiyonu herkese açık yazılabilirdi; herhangi bir kimliği doğrulanmış kullanıcı, doğrudan Firestore aracılığıyla kendisine sınırsız premium durumu verebilirdi. Davet kullanımı, Firestore transaction'ı ile Admin SDK altında çalışan bir sunucu tarafı Cloud Function'a (`redeemReferralCode`) taşındı; istemci kuralları artık `founding_member`, `premium_access_until` ve `referred_by_code` alanlarına yapılan tüm güncellemeleri reddediyor.
- **[KRİTİK DÜZELTME]** Anthropic API anahtarı `--dart-define` aracılığıyla derlenmiş istemci binary'sine gömülmüştü. Anahtar tümüyle istemciden kaldırıldı; tüm AI çağrıları artık Firebase Secret Manager'da anahtarı tutan `anthropicProxy` Cloud Function üzerinden yapılıyor. Günlük katman bazlı kullanım kotaları (quick: 300, deep: 60) sunucu tarafında Firestore transaction'ı ile uygulanıyor.
- Firebase App Check etkinleştirildi (yayında Play Integrity / App Attest; hata ayıklamada debug sağlayıcı). `anthropicProxy`, `redeemReferralCode`, `deleteAccount` fonksiyonlarında zorunlu tutuldu.
- `habits` ve `habit_completions` koleksiyonlarında Firestore kuralı yoktu — tüm alışkanlık yazmaları üretimde sessizce başarısız oluyordu. Sahip kapsamlı kurallar eklendi.
- `deleteAccount` Cloud Function: Firestore verilerinin, Storage dosyalarının, Supabase kimliğinin ve Firebase Auth kullanıcısının basamaklı silinmesi.
- Firebase Crashlytics `FlutterError.onError` ve `PlatformDispatcher.onError`'a bağlandı.

### Eklendi

- Tam uluslararasılaştırma (TR/EN) — ~270 yerelleştirilmiş dize; ICU çoğullama; flutter_localizations + intl; .arb kaynak dosyaları.
- Gizlilik Politikası ve Kullanım Şartları ekranları, kayıt formundan ve profil ayarlarından bağlantılı; auth öncesinde erişilebilir.
- Uygulama içi hesap silme akışı (iki adımlı onay → Cloud Function → basamaklı veri silme). Apple App Store Kılavuzu 5.1.1(v) tarafından zorunlu tutulmaktadır.
- Vibe Card — haftalık refah özet kartı (9:16 hikaye biçimi); PNG olarak yakalanır, share_plus ile paylaşılır.
- Davet sistemi — davet kodu oluşturma, sunucu tarafı kullanım, kurucu üye ödülü (7 günlük premium uzantısı, mevcut üzerine eklenir).
- Alışkanlık takibi — alışkanlık ekleme/silme, günlük geçiş (artık Firestore transaction'ı ile atomik), Takip ekranında haftalık istatistikler.
- CI/CD — GitHub Actions: her push/PR'da analiz + test + format + debug derleme; sürüm etiketlerinde imzalı yayın AAB.
- Firestore bileşik dizinler `firestore.indexes.json` dosyasına eklendi.
- İçerik hattı: `content/articles.json` + idempotempt `seedArticles.js` Admin SDK upsert betiği.
- Test paketi: 43 Flutter testi + 14 Cloud Function testi.

### Değiştirildi

- Koyu mod artık auth dahil her ekranı kapsıyor.
- `Pressable` widget'ı: devre dışı durum 150 ms animasyonla 0,45 opaklığa düşüyor.
- `toggleCompletion` Firestore transaction'ına sarıldı.
- Uygulama başlatma: her servis bağımsız try/catch'e sarıldı.
- Android `build.gradle.kts`: koşullu yayın imzalama.

### Kaldırıldı

- `name_input_screen.dart`, `onboarding_questions_screen.dart`, `value_props_screen.dart` — birleştirildi.
- `cupertino_icons` bağımlılığı — kullanılmıyor.
- Düz metin kimlik bilgisi dosyaları.

### Düzeltildi

- Doğrulayıcı hata mesajları artık l10n dizeleri kullanıyor.
- `paywall_screen.dart` async çağrı sonrası eksik `mounted` kontrolü.
- `signOut()` artık hata durumunda `AuthError` döndürüyor.

---

## Önceki

Önceki yayın yok — bu ilnd'nin ilk sürümüdür.
