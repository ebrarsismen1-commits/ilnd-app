# ADR-0005: Rehberli planlar — 7/14/21 basamağı, şema ve ilerleme

**Status:** Accepted
**Date:** 2026-08-07

## Decision
Rehberli planlar `plans` adında kök bir Firestore koleksiyonunda (Admin SDK ile
seed edilir, istemciye salt-okunur) tutulur; bir plan **7, 14 veya 21 günlük**
sıralı bir gün dizisidir, her gün **tek bir içerik referansı + en fazla tek
eylem** taşır; ilerleme `users/{uid}/plan_progress/{planId}` altında yaşar ve
**aynı anda yalnız bir plan aktiftir**. 7 günlük basamak ücretsiz, 14 ve 21
ILND+'a kilitlidir.

## Context
Pazarlama sitesi (ilnd.app) ürünün merkezine "30 günlük planlar"ı koymuş
durumda ve altı tema sayıyor (yoga, okuma, yaratıcılık, anne, sağlık,
bütünsel); ayrıca iki ayrı CTA "7 günlük ücretsiz rehber" indirtiyor.
Uygulamada plan kavramı **hiç yok** — ziyaretçinin göreceği ürün sitedekinden
farklı. Bu ADR o boşluğu kapatan sistemi tanımlar.

Kısıtlar:
- **Süre kararı sahibinden geldi: 30 değil 7/14/21.** İlk zaferi 30 gün yerine
  7 günde vermek tamamlanma oranı lehinedir; site metni "30 günlük yolculuk =
  7 + 14 + 21 basamağı" olarak okunacak biçimde çerçevelenir.
- İçerik hattı zayıf: elde 10 makale var, video yok. Altı temanın her biri için
  42 günlük içerik (toplam 252 parça) üretilemez.
  **Güncelleme (onay anında):** sahip lansman için ~200 yazı üretebileceğini
  bildirdi. Bu, kısıtı gevşetir ama kararı değiştirmez — gün↔makale bağı
  içeriği iki yerde çalıştırdığı için hâlâ doğru; 14 ve 21 günlük basamaklar
  da lansmanda açılabilir hâle gelir.
- Nav v2 (4 sekme + merkez nefes halkası) kapalı bir karardır; planlar yeni bir
  sekme açamaz.
- Ürün ilkesi: içerik yokken raf gösterilmez (ADR-0004'te de uygulandı).
- Ücretsiz katman zaten sunucuda ölçülüyor (Sert Kural #13); plan kilidi bu
  mimariyle çelişmemeli.

## Alternatives
1. **Planları `articles` koleksiyonuna sıkıştırmak.** Elendi — ADR-0004'te aynı
   gerekçeyle elenmişti: makale tek parçadır, plan sıralı ve ilerleme
   takipli bir yapıdır. `Article`'ı üçüncü kez şişirirdi.
2. **Planı `movement_programs` içine bir tür olarak eklemek.** Cazip: şema
   neredeyse aynı. Elendi — hareket programı *seans* dizisidir (video), plan
   *gün* dizisidir ve günün içeriği makale de olabilir nefes de. İki kavramı
   tek dokümanda tutmak "hangi alan hangi tür için geçerli" sorusunu her okuma
   noktasına dağıtır.
3. **Gün başına çok adımlı plan** (site "07:00 / 12:30 / 20:00" diyor).
   Elendi (şimdilik) — üç adımlı gün, gün ortasında yarım kalma olasılığını
   üçe katlar. Gün ritmi ayrı bir iş olarak (push penceresi) gelir; plan günü
   tek adım kalır.
4. **Aynı anda birden çok aktif plan.** Elendi — "üç plan başlatıp hiçbirini
   bitirmemek" en sık görülen wellness başarısızlığı; ürün tonu da (non-preachy,
   tek şey) buna aykırı.
5. **Planı tamamen AI'a kurdurmak** (her kullanıcıya özel 7 gün üretmek).
   Elendi — maliyet öngörülemez, içerik denetlenemez, kriz güvenlik ağı dışında
   metin üretir. AI planı *kişiselleştirir* (günün notunu kullanıcının
   hafızasına göre yazar), planı *kurmaz*.

## Pros / Cons
+ `movement_programs` deseninin birebir tekrarı: kurallar, seed script'i,
  salt-okunur erişim ve ilerleme takibi kanıtlanmış biçimde ayrışır.
+ Gün → `articleId` referansı içeriği ikiye katlamadan iki yerde çalıştırır:
  plan içinde sıralı, Keşfet'te bağımsız okunur. 10 mevcut makale yeniden
  kullanılır, çöpe gitmez.
+ 7 günlük ücretsiz basamak sitedeki "ücretsiz rehber" sözünü PDF üretmeden
  karşılar ve paywall'ı doğal yere koyar (kullanıcı değeri görmüşken).
+ Tek aktif plan, "Bugün" ekranında tek bir net eylem demek — ana ekranın
  kalabalıklaşmasını da sınırlar.
− Yeni kök koleksiyon = yeni kural, yeni index, yeni seed script; deploy
  edilmezse prod'da ölü (ADR-0004'te bu bedel yaşandı).
− `premium` alanı içerik kararı olduğu için basamak kilidi JSON'da yaşar;
  yanlış işaretlenen bir plan ücretsiz açılır. Seed doğrulamasıyla kapatılmalı.
− Plan ilerlemesi kullanıcının yazabildiği bir dokümanda tutulur; rozet ve
  "tamamlama oranı" bu yüzden **övünç verisidir, hak verisi değildir** —
  premium hakkı asla buraya bakmaz (Sert Kural #13'ün mantığı).
− Site "30 gün" derken uygulama 7/14/21 diyecek; metin çerçevesi tutmazsa
  tutarsızlık kullanıcıya görünür.

## Reason
Belirleyici gerekçe **içerik ekonomisi**: plan günü ile makaleyi aynı içerik
parçasına bağlamak, 252 parçalık imkânsız üretim hedefini lansman için 21
parçaya indiriyor (3 tema × 7 gün) ve mevcut 10 makaleyi bu havuzun içine
sokuyor. Şemayı `movement_programs` deseninden türetmek ise yeni bir mimari
tartışması açmadan aynı garantileri (salt-okunur içerik, ayrık ilerleme,
içerik yokken raf yok) getiriyor.

## Consequences
- `content/plans.json` + `functions/scripts/seedPlans.js` doğar; `plans`
  koleksiyonu **yalnız Admin SDK** ile yazılır (`allow write: if false`).
- Yayınlanabilirlik kuralı ADR-0004'teki gibi: **günü olmayan plan çizilmez**,
  günü eksik plan hiç gösterilmez. Yarım içerik boş vaattir.
- Plan ilerlemesi kullanıcıya bağlı bir provider'dır → Sert Kural #2 geçerli:
  hem `authNotifierProvider` hem `firebaseAuthUidProvider` izlenir.
- Plan bitişi paylaşılabilir kart üretir; kart Sert Kural #14'e tabidir (esnek
  layout + dar viewport testi).
- Kilit kararı tek kapıdan geçer: `UsageGate`/`hasPremiumAccessProvider` —
  ikinci bir premium kontrolü yazılmaz.
- Tüm plan metinleri `.arb`'de değil **içerikte** yaşar (makale gövdesi gibi);
  ama arayüz etiketleri (buton, durum, bölüm başlığı) `.arb`'dedir ve Sert
  Kural #16'daki üslup testlerine eklenir.
- Site metni "30 günlük yolculuk = 7 + 14 + 21" çerçevesine çekilmezse bu ADR
  yarım kalır — belge dışı ama takipli bir yükümlülük.

## Future Impact
Planların AI ile kişiselleştirilmesi (günün notunu hafızaya göre yazmak) bu
şemayı değiştirmeden eklenebilir — gün dokümanı sabit kalır, üstüne üretilen
metin kullanıcıya özel olur. Şemayı değiştirtecek iki şey: (1) gün başına çok
adımlı yapıya geçme kararı — `days[].steps[]` alanına genişleme gerekir,
geriye dönük uyumlu; (2) planların kullanıcı tarafından oluşturulabilir hâle
gelmesi (koç/creator fazı) — o zaman `plans` salt-okunur olmaktan çıkar ve
yazma kuralları baştan yazılır. Geri alma maliyeti düşük: koleksiyon ve
ilerleme dokümanları silinir, uygulama plan öncesi hâline döner.
