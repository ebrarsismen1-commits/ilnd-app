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

### 3. Altı öğenin hepsi kazanılabilir

| Öğe | Eşik |
|---|---|
| fener | ilk günlük |
| çam | 3 gün seri |
| fırın | 10 öğün |
| rüzgâr gülü | 7 gün seri |
| ay ışığı | ilk gece ritüeli |
| buluşma taşı | ilk topluluk buluşması |

**Güncelleme (2026-08-20, yayın öncesi denetim):** ilk sürümde son iki öğe
"kilitli" bırakılmıştı, çünkü kaynakları sunucudan okunamıyordu. Yayın
denetiminde bu bir sorun olarak işaretlendi: hiç kazanılamayan bir öğeyi
listede göstermek, deponun kendi ilkesine (asla sahte özellik göstermeyiz)
aykırı. İkisi de kapatıldı:

- **ay ışığı** — gece ritüeli tamamlanması artık `users/{uid}/sleep_rituals/
  {tarih}` altına da yazılıyor. Cihazdaki bayrak duruyor ("bu gece daveti
  tekrar gösterme" için) ama kalıcı kayıt hesapta. Bu aynı zamanda cihaz
  değiştiren kullanıcının ritüel geçmişini kaybetmesini de düzeltiyor —
  Sert Kural #13'ün sınıfı.
- **buluşma taşı** — RSVP dokümanları zaten `userId` alanı taşıyordu;
  `rsvps` için tek alanlı bir collectionGroup indeksi eklendi
  (firestore.indexes.json) ve fonksiyon aggregate `count()` ile sayıyor.

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
