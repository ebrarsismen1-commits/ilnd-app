# Sık Sorulan Sorular

## Genel

### ilnd nedir?

ilnd ("iyi hisset, iyi yaşa"), Gen-Z refahı için geliştirilmiş bir günlük tutma uygulamasıdır. Günlük günlük tutma alışkanlığını, girişlerinden öğrenen ve kişiselleştirilmiş içgörülerle yanıt veren bir AI arkadaşıyla (ILND) birleştirir. Uygulama aynı zamanda alışkanlıkları, beslenmeyi ve haftalık refah trendlerini Vibe Card özelliği aracılığıyla takip eder.

### ilnd hangi platformları destekliyor?

iOS 16+ ve Android 8+ (API 26). Flutter her iki platformda aynı arayüzü oluşturur.

### Uygulama hangi dillerde mevcut?

Uygulama tam Türkçe (TR) ve İngilizce (EN) desteğiyle gelir. Aktif yerel ayar, cihaz dil ayarını izler; desteklenmeyen yerel ayarlar için TR varsayılandır.

### ilnd ücretsiz mi?

Temel günlük tutma ve alışkanlık takibi özellikleri ücretsizdir. Premium katman (ilnd+), sınırsız AI konuşmaları ve derin katman AI yanıtlarının kilidini açar. Premium, RevenueCat aboneliği veya davet ödülü aracılığıyla verilir.

---

## Teknik

### Uygulama neden hem Supabase hem Firebase kullanıyor?

Supabase, kimlik doğrulama arayüzünü yönetir. Firebase, Firestore (veritabanı), Cloud Functions (sunucu mantığı) ve App Check'i (istek doğrulama) çalıştırır. Aralarındaki köprü, bir Supabase JWT'sini Firebase özel token'ına dönüştüren `mintFirebaseToken` Cloud Function'ıdır. Bu, Firestore güvenlik kurallarının `request.auth.uid` kullanmasına izin verir.

### Anthropic API anahtarı neden uygulama binary'sinde değil?

İstemci binary'sindeki bir API anahtarı, standart APK/IPA analiz araçlarıyla herhangi bir APK veya IPA'dan çıkarılabilir. Anahtar Firebase Secret Manager'da saklanır ve yalnızca `anthropicProxy` Cloud Function tarafından erişilir. İstemci mesajları gönderir ve yanıtları alır — anahtarı hiçbir zaman görmez.

### Davet sistemi nasıl çalışıyor?

Her kullanıcı `user_growth/{uid}.referral_code` alanında benzersiz bir davet kodu alır. Yeni bir kullanıcı kodu kullandığında, `redeemReferralCode` Cloud Function:
1. Kodu doğrular ve kendine daveti engeller
2. Davet edene 7 günlük premium verir (mevcut premiuma eklenir)
3. Yeni kullanıcıyı kurucu üye olarak işaretler
4. Daveti Firestore'a kaydeder

İstemci, premium durumu doğrudan değiştiremez — her şey sunucu tarafındadır.

### AI kullanım limitleri nasıl uygulanıyor?

`anthropicProxy` Cloud Function, isteği Anthropic'e iletmeden önce `ai_usage/{uid}/{tier}/{bugün}` sayacını bir Firestore transaction'ı içinde artırır. Sayı günlük limiti aşarsa fonksiyon 429 döner. İstemci, modeli veya limitleri geçersiz kılamaz — her ikisi de sunucu tarafında ayarlanır.

### Hesap silindiğinde kullanıcı verilerine ne olur?

`deleteAccount` Cloud Function basamaklı silme yapar:
1. `users/{uid}/` altındaki tüm Firestore belgeleri
2. `user_growth/{uid}` belgesi
3. Bu kullanıcı için `referrals` belgeleri
4. `users/{uid}/` altındaki Firebase Storage dosyaları
5. Supabase Auth kullanıcısı (en iyi çaba)
6. Firebase Auth kullanıcısı

Apple App Store Kılavuzu 5.1.1(v) tarafından zorunlu tutulmaktadır.

### `mintFirebaseToken` neden App Check ile korunmuyor?

App Check, isteğin gerçek bir uygulama binary'sinden geldiğini doğrular. Yayın sırasında App Check zorunluluğu başarısız olursa (cihaz doğrulama sorunları, yeni cihaz türleri vb.), kullanıcılar kurtarma yolu olmadan girişe erişimi tamamen kaybedebilir. Fonksiyon bunun yerine Supabase JWT'sini doğrular — bu giriş noktası için yeterlidir.

---

## Geliştirme

### Yeni yerelleştirilmiş dize nasıl eklerim?

1. `lib/l10n/app_tr.arb` dosyasına ekle (Türkçe şablon)
2. `lib/l10n/app_en.arb` dosyasına aynı anahtarı ekle (İngilizce çeviri)
3. `flutter gen-l10n` komutunu çalıştır
4. Widget'larda `AppLocalizations.of(context)!.anahtarim` kullan

### Geliştirme sırasında AI kullanım sayacımı nasıl sıfırlarım?

[http://localhost:4000](http://localhost:4000) adresindeki Emülatör Arayüzü'nü aç, Firestore'a git ve `ai_usage/{uid}/quick/{bugün}` veya `ai_usage/{uid}/deep/{bugün}` belgesini sil.

### Widget testlerinde `pumpAndSettle()` neden zaman aşımına uğruyor?

`AnimatedBackground` sonsuz animasyon kullanır. `pumpAndSettle()`, tüm animasyonlar yerleşene kadar bekler — bu, sonsuz animasyon için asla gerçekleşmez. Bunun yerine `await tester.pump()` + `await tester.pump(Duration(milliseconds: 100))` kullan.

### Uygulamayı Firebase olmadan kullanabilir miyim?

Hayır. Firebase Firestore birincil veritabanıdır. Günlük girişleri, alışkanlıklar ve kullanıcı büyüme verileri olmadan saklanamaz veya alınamaz.

---

## İçerik

### Makaleler nasıl yönetiliyor?

Makaleler `content/articles.json` dosyasında saklanır ve seed betiği kullanılarak Firestore'a yüklenir:
```bash
cd functions
npm run seed:articles
```

Uygulama ayrıca, Firestore erişilemez olduğunda çevrimdışı geri dönüş olarak hizmet eden bir `kArticles` Dart sabiti de içerir.

### Yeni makale nasıl eklerim?

1. `content/articles.json` dosyasına benzersiz `id` alanı olan bir giriş ekle
2. Firestore'a göndermek için `npm run seed:articles` komutunu çalıştır
3. Uygulama bunu anında gösterecektir — uygulama güncellemesi gerekmez

---

## Dağıtım

### İmzalı Android derlemesini nasıl alırım?

Bir sürüm etiketi gönder (örn. `v1.0.0`). GitHub Actions yayın iş akışı, depoda yapılandırılan keystore sırlarını kullanarak AAB'yi derler ve imzalar. İmzalı AAB, iş akışı eseri olarak yüklenir.

### Fonksiyonları dağıtmadan önce hangi Firebase sırları ayarlanmalı?

```bash
firebase functions:secrets:set ANTHROPIC_API_KEY
firebase functions:secrets:set SUPABASE_SERVICE_ROLE_KEY
```

Her ikisi de ilk `firebase deploy --only functions` öncesinde ayarlanmalıdır.

### `seedArticles.js` birden fazla kez çalıştırmak güvenli mi?

Evet. Betik, `id` alanı üzerinde anahtarlanmış idempotempt upsert işlemleri gerçekleştirir. İki kez çalıştırmak, bir kez çalıştırmakla aynı sonucu üretir.

---

## İlgili Belgeler

- [SORUN_GIDERME.md](SORUN_GIDERME.md) — hata tanılama
- [KURULUM.md](KURULUM.md) — yerel kurulum
- [MIMARI.md](MIMARI.md) — sistem tasarımı
