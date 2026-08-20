# ADR-0006 — Adan: ilerlemenin yer olarak gösterimi

- **Durum:** Kabul edildi
- **Tarih:** 2026-08-19
- **Bağlam kaynağı:** tasarım handoff (design_handoff_ilnd_redesign) §7 "Adan"

## Bağlam

Uygulama ilerlemeyi bugüne kadar hep **sayı** olarak gösterdi: streak günü,
puan, rozet adedi. Sayı motive ediyor ama biriktirmiyor — kullanıcı 40. günde
de 4. günde de aynı ekranı görüyor, yalnız rakam değişiyor.

Tasarım handoff'u bunun yerine bir **yer** öneriyor: tamamlanan işler ada
öğesi kazandırır (fener, çam, fırın, ay ışığı, rüzgâr gülü, buluşma taşı),
öğeler adaya yerleşir ve ada zamanla kullanıcının hafızasının haritası olur.

Kritik ürün kuralı (handoff §7, ses tonu §6): **hiçbir öğe geri alınmaz.**
Sessiz geçen günler yalnız suyu koyulaştırır — ceza yok.

## Karar

### 1. Öğe kazanımı SUNUCUDA hesaplanır ve SUNUCUDA yazılır

Öğeler `island/{uid}` dokümanında tutulur. İstemci bu dokümanı **yalnız
okur**; `firestore.rules` içinde `allow write: if false`.

Kazanım `syncIslandItems` Cloud Function'ı ile olur: fonksiyon kullanıcının
kendi verisini (günlük, öğün, check-in) Admin SDK ile okur, eşikleri
karşılaştırır ve yeni kazanılan öğeleri yazar.

**Gerekçe:** bu tam olarak Sert Kural #13'ün doğduğu hata sınıfı. Kullanım
kotası bir zamanlar SharedPreferences'taydı; silince sıfırlanıyordu ve web
ile mobil ayrı sayıyordu. Kullanıcının yazabildiği yerde sınır yoktur —
kullanıcının yazabildiği yerde **ödül de yoktur**. İstemci öğe verebilseydi
"ada" bir hafıza haritası değil, düzenlenebilir bir vitrin olurdu.

### 2. Eşikler tek kaynaktan gelir, iki yerde kodlanır

Eşik tablosu hem sunucuda (`functions/index.js` `ISLAND_ITEMS`) hem istemcide
(`adan_model.dart` `kIslandItems`) durur. İstemcideki kopya **yalnız
gösterim** içindir (kilitli öğenin "nasıl kazanılır" satırı); kazanım
kararını asla vermez. İkisinin aynı kaldığı testle kilitlenir.

### 3. Bu turda dört öğe kazanılabilir, ikisi kilitli görünür

| Öğe | Eşik | Durum |
|---|---|---|
| fener | ilk günlük | kazanılabilir |
| çam | 3 gün seri | kazanılabilir |
| fırın | 10 öğün | kazanılabilir |
| rüzgâr gülü | 7 gün seri | kazanılabilir |
| ay ışığı | ilk gece ritüeli | **kilitli** |
| buluşma taşı | ilk topluluk buluşması | **kilitli** |

Son ikisi sunucudan doğrulanamıyor: gece ritüeli tamamlanması yalnız
SharedPreferences'ta (cihaz-yerel), RSVP ise `events/{id}/rsvps/{uid}`
alt koleksiyonunda — collectionGroup sorgusu ve indeks gerektiriyor.
İkisi de listede **kilitli** görünür; bu tasarımın kendi sözlüğünde zaten
var olan bir durum, uydurma değil.

Kilitli kalmaları geçici: gece ritüeli için Firestore'a tamamlanma kaydı
yazmak, RSVP için collectionGroup indeksi açmak gerekiyor. İkisi de ayrı iş.

### 4. Ada görseli bu turda YOK

Handoff üç katmanlı (su / kara / öğe) gerçek bir illüstrasyon ve öğe başına
bir sprite istiyor. Owner kararı (2026-08-19): görsel sonra hazırlanacak,
şimdilik ada alanı sade bir yüzey olarak durur. Öğe listesi ve kazanım
mantığı görselsiz de tam çalışır.

## Sonuçlar

**İyi:** ödül sistemi ilk günden sunucu-otoritatif; istemci sürümü eski kalsa
da kimse kendine öğe veremez. Ada, silinmeyen tek ilerleme kaydı olur.

**Maliyet:** her kazanım kontrolü bir fonksiyon çağrısı. Çağrı, ekran
açılışında ve öğe kazandıracak eylemlerden sonra yapılır — her build'de
değil.

**Risk:** eşik tablosu iki yerde. Test aynı kalmalarını kilitler; yine de
yeni öğe eklerken iki dosyaya birden dokunmak gerektiği unutulmamalı.

## Alternatifler

- **İstemcide hesapla, Firestore'a yaz:** hızlı ama kotadaki hatanın aynısı;
  kullanıcı konsoldan kendine bütün adayı verebilirdi. Reddedildi.
- **Firestore trigger (onWrite) ile kazan:** her günlük/öğün yazımında
  tetiklenir, çağrı gerekmez. Reddedildi: altı ayrı tetikleyici ve kısmi
  başarısızlıkta tutarsız durum demek; tek bir "senkronize et" fonksiyonu
  idempotent ve tekrar çalıştırılabilir.
