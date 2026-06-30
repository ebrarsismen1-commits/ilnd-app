/// Gizlilik Politikası ve Kullanım Şartları metinleri.
///
/// ilnd ruh hali/günlük/yemek gibi hassas kişisel veri topladığı için bu
/// ekranlar Apple/Google'ın zorunlu tuttuğu açık disclosure'ı sağlar —
/// hesap silme akışı (profile_screen.dart) burada anlatılan "verilerini
/// sil" hakkının karşılığıdır.
abstract final class LegalContent {
  static const lastUpdated = '30 Haziran 2026';

  static const privacyPolicy =
      '''
Son güncelleme: $lastUpdated

ilnd ("biz", "uygulama") gizliliğine önem verir. Bu politika hangi verileri topladığımızı, neden topladığımızı ve verilerin nasıl kullanıldığını açıklar.

TOPLADIĞIMIZ VERİLER
• Hesap bilgileri: e-posta adresi, isim (Supabase üzerinden kimlik doğrulama).
• İçerik verisi: günlük yazıların, ruh hali kayıtların, yemek girişlerin, alışkanlık/seri takibin (Firebase Firestore'da saklanır).
• Kullanım verisi: uygulama açılışları, özellik kullanımı (Firebase Analytics).
• Cihaz/teknik veri: işletim sistemi, uygulama sürümü, çökme/hata günlükleri.
• Abonelik durumu: RevenueCat üzerinden satın alma/abonelik bilgisi (kart bilgilerin bize hiç ulaşmaz, Apple/Google tarafından işlenir).

VERİLERİ NASIL KULLANIYORUZ
• Uygulamanın temel işlevini (günlük, ruh hali takibi, ILND ile sohbet) sağlamak.
• ILND'nin sana kişiselleştirilmiş yanıt verebilmesi için günlük/sohbet metnin, isteğin üzerine bizim sunucumuz üzerinden (anahtar hiçbir zaman cihazında tutulmaz) Anthropic'in yapay zeka modeline iletilir.
• Ürünü iyileştirmek için anonimleştirilmiş kullanım istatistikleri.
• Abonelik/ödeme durumunu doğrulamak.

KİMLERLE PAYLAŞIYORUZ
Verilerini reklam amacıyla satmıyoruz. Uygulamanın çalışması için şu hizmet sağlayıcılarla paylaşılır: Supabase (kimlik doğrulama), Google Firebase (veritabanı, analytics), RevenueCat (abonelik yönetimi), Anthropic (yapay zeka yanıtları — sadece gönderdiğin metin, sunucumuz üzerinden, kalıcı olarak saklanmaz).

VERİ SAKLAMA VE SİLME
Verilerin hesabın aktif olduğu sürece saklanır. Profil > Ayarlar > "hesabımı sil" ile hesabını ve tüm verilerini (günlükler, yemek kayıtları, seri geçmişi, abonelik bağlantısı) kalıcı ve geri alınamaz şekilde silebilirsin. Silme işlemi sunucularımızdan ve kimlik doğrulama sağlayıcılarımızdan veriyi kaldırır.

HAKLARIN
Verilerine erişme, düzeltme ve silme hakkına sahipsin. Silme talebini doğrudan uygulama içinden gerçekleştirebilir, ya da bizimle iletişime geçebilirsin.

ÇOCUKLARIN GİZLİLİĞİ
ilnd 13 yaş altı kullanıcılara yönelik değildir ve bilerek bu yaş grubundan veri toplamaz.

İLETİŞİM
Sorularını privacy@ilnd.app adresine iletebilirsin.
''';

  static const termsOfService =
      '''
Son güncelleme: $lastUpdated

Bu Kullanım Şartları ("Şartlar"), ilnd uygulamasını kullanımını düzenler. Uygulamayı kullanarak bu Şartları kabul edersin.

HİZMETİN TANIMI
ilnd; ruh hali takibi, günlük yazma, alışkanlık takibi ve yapay zeka destekli sohbet (ILND) sunan bir kişisel iyi olma uygulamasıdır. Tıbbi tavsiye, tanı veya tedavi yerine geçmez — ruh sağlığıyla ilgili kriz durumunda lütfen bir uzmana veya yerel acil yardım hattına başvur.

HESABIN
13 yaşından büyük olmalısın. Hesap bilgilerinin gizliliğinden ve hesabın üzerinden yapılan işlemlerden sen sorumlusun.

ABONELİK VE ÖDEMELER
ilnd+ premium özellikleri, Apple App Store / Google Play üzerinden yönetilen otomatik yenilenen bir abonelik aracılığıyla sunulur. Abonelik, mevcut dönem bitmeden en az 24 saat önce iptal edilmediği takdirde otomatik olarak yenilenir. İptal ve geri ödeme talepleri Apple/Google'ın kendi politikalarına tabidir.

KABUL EDİLEBİLİR KULLANIM
Uygulamayı yasalara aykırı amaçlarla, başka kullanıcıların verilerine yetkisiz erişim sağlamak için, ya da servisin (özellikle yapay zeka sohbet özelliğinin) makul kullanım sınırlarını kötüye kullanacak şekilde (otomasyon, toplu istek) kullanamazsın.

İÇERİK
Günlük/sohbet içeriğin sana aittir. Bu içeriği yalnızca hizmeti sana sunmak için (ör. ILND'nin yanıt üretmesi) işleriz; reklam veya üçüncü taraf eğitim amacıyla kullanmayız.

SORUMLULUĞUN SINIRLANDIRILMASI
Hizmet "olduğu gibi" sunulur. Yasaların izin verdiği ölçüde, dolaylı zararlardan sorumlu değiliz.

DEĞİŞİKLİKLER
Bu Şartları güncelleyebiliriz; önemli değişiklikleri uygulama içinden bildiririz.

İLETİŞİM
Sorularını legal@ilnd.app adresine iletebilirsin.
''';
}
