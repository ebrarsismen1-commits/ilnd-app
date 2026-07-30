# ADR-0004: Hareket programları — şema, yerleşim ve video kaynağı

**Status:** Accepted
**Date:** 2026-07-30

## Decision
Video tabanlı hareket programları, `movement_programs` adında kök bir Firestore
koleksiyonunda (Admin SDK ile seed edilir, istemciye salt-okunur) tutulur;
uygulamada **Keşfet içinde ayrı bir raf** olarak yaşar; videolar **Firebase
Storage**'da barınır ve `video_player` paketiyle uygulama içinde oynatılır.

## Context
Ürün, hareket için bugün yalnızca `movement_pool.dart` içindeki 8 kod-içi metin
önerisine sahip: Bugünün Üçlüsü'ndeki "Hareket" kartı bir cümle gösteriyor,
hiçbir ekrana açılmıyor. Sahibi, video tabanlı program desteğinin **altyapısının**
şimdi kurulmasını istedi — elde henüz tek bir video yok.

Kısıtlar:
- Nav v2 (4 sekme + merkez nefes halkası) bilinçli bir tasarım kararı; beşinci
  sekme halka simetrisini bozar.
- Tasarım vizyonu bu içerik tipini zaten konumlandırmış: *"Grid'e yeni içerik
  tipleri raf olarak girer: video ritüel, koç programı…"* (§Keşfet/Ölçek).
- `Article.videoUrl` alanı yıllar önce eklenmiş ama oynatıcısı hiç yazılmamış —
  yarım kalmış bir başlangıç mevcut.
- Ürün ilkesi: **asla sahte özellik gösterilmez**. İçerik yokken raf da yoktur.
- Web birinci sınıf yüzey (kullanıcıların bir kısmı web'de); seçilen oynatıcı
  web'de de çalışmak zorunda.

## Alternatives
1. **Alt navigasyonda 5. sekme.** Görünürlük en yüksek. Elendi: nav v2 kararını
   ve halka simetrisini bozuyor; içerik henüz yokken kalıcı boş bir sekme
   "sahte özellik" demek.
2. **Bugün'deki Hareket kartından açılan tek ekran.** Retention çekirdeğine
   bağlı kalır ama katalog keşfedilemez — kullanıcı yalnız günün seansını
   görür, program kavramı doğmaz.
3. **YouTube/Vimeo (unlisted) embed.** Bant genişliği bedava. Elendi: oynatıcı
   bizim değil (marka dışı UI, "sonraki video" önerileri, reklam riski),
   web'de iframe + mobilde ayrı paket gerekir, Vimeo Pro ücretli.
4. **Sağlayıcı-bağımsız soyutlama, oynatıcı sonraya.** En az bağımlılık.
   Elendi: "video desteğiyle çalışmalı" isteği bugün karşılanmaz; ilk video
   geldiğinde ikinci bir iş açılır.
5. **Programları `articles` koleksiyonuna sıkıştırmak** (mevcut `videoUrl`
   alanını kullanarak). Elendi: makale tek parçadır, program çok-seanslı ve
   sıralı bir yapıdır; ilerleme takibi seans kimliği ister. Aynı dokümana iki
   ayrı şekil sığdırmak `Article`'ı üçüncü kez şişirirdi (zaten tarif alanları
   yüzünden şişkin).

## Pros / Cons
+ Keşfet rafı: nav değişmeden yeni içerik tipi eklenir; vizyonun kendi planı.
+ Kendi Storage'ımız: marka deneyimi bizde, reklam/öneri kirliliği yok, aynı
  Firebase projesi (ek panel/hesap yok), imzalı URL'lerle ileride erişim
  kısıtlanabilir.
+ `video_player` endorsed web/Android/iOS implementasyonlarıyla gelir.
+ Ayrı koleksiyon: kurallar, index'ler ve ilerleme takibi temiz ayrışır.
− Storage bant genişliği ücretli (~$0.12/GB): ölçekte HLS/transcoding veya CDN
  gerekir; pilotta önemsiz, ölçekte ölçülmeli.
− `video_player` bir platform bağımlılığı: `flutter test` içinde platform
  arayüzü sahtelenmeden oynatıcı test edilemez.
− Video üretim maliyeti (çekim, kurgu, altyazı) üründe yeni bir iş kolu açar.

## Reason
Yerleşim kararında belirleyici olan, vizyon dokümanının bu içerik tipini zaten
Keşfet rafı olarak konumlamış olması: nav v2'yi bozmadan büyüme yolu bu.
Video kaynağında belirleyici olan marka deneyimi — ILND'nin tonu "warm,
minimal, non-preachy"; YouTube oynatıcısının önerileri ve reklamları bu tonu
uygulamanın içinde kıramayacağımız bir biçimde deler. Bant genişliği maliyeti
ölçülebilir ve ertelenebilir bir sorun, marka deneyimi ise geri alınamaz.

## Consequences
- `movement_programs` koleksiyonu **yalnız** Admin SDK ile yazılır
  (`content/movementPrograms.json` + `functions/scripts/seedMovementPrograms.js`,
  `articles`/`events` emsali). firestore.rules: `allow read: if request.auth != null`,
  `allow write: if false`. Kuralsız koleksiyon prod'da ölüdür.
- Kullanıcı ilerlemesi `users/{uid}/movement_progress/{programId}` altında —
  mevcut `users/{uid}/{document=**}` kuralı kapsar, ayrı kural gerekmez.
  Kota/hak değil, ilerleme olduğu için istemcinin yazması sorun değil
  (Sert Kural #13 yalnız sınır/kota için geçerlidir).
- İçerik boşken Keşfet rafı **hiç render edilmez** — boş raf gösterilmez.
- Video dosyaları Storage'da `movement/{programId}/{sessionId}.mp4` düzeninde
  durur; `deleteAccount` bunlara dokunmaz (kullanıcı verisi değil, içerik).
- `movement_pool.dart` (Bugün'ün Hareket kartı) yerinde kalır: video programı
  farklı bir vaattir, günlük mikro-öneriyi ikame etmez.
- Premium alanı şemada baştan var; kilitli program kartı paywall açar. Hangi
  programın premium olacağı içerik kararıdır, kod kararı değil.

## Future Impact
Ölçekte üç şey bu kararı zorlar: (1) bant genişliği faturası — cevabı Storage'ın
önüne CDN/HLS koymak, şema değişmez; (2) çevrimdışı izleme talebi — indirme
katmanı `MovementSession.videoUrl` üzerine eklenir; (3) canlı/kohort programlar —
o gün `movement_programs` dokümanına takvim alanları eklenir ya da ayrı bir
koleksiyon doğar. Geri alma maliyeti düşük: koleksiyon ve ekranlar bağımsız,
`video_player` yalnız oynatıcı widget'ında geçer; sağlayıcı değişirse tek
dosya değişir.
