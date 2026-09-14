# Ada görsel entegrasyonu — 14 Eylül 2026

Kullanıcının ada illüstrasyonu temel alınarak ortak, statik sahne eklendi.
Son kullanıcı yönlendirmesiyle ada, selamlamadan hemen sonra ve günlük
öneriden önce gelir; 160–220 px önizleme yüksekliği korunur.
Adan ekranı aynı sahneyi ve aynı sunucu kaynaklı kazanımları büyük gösterir.
Lora / DM Sans, mevcut palet ve 24 px çerçeve korunur.

## Dosyalar ve davranış

- `assets/island/terrain-v2.webp`: şeffaf ada, sabit kamp ateşi dahil.
- `assets/island/objects-v2.webp`: 3×2 şeffaf atlas; fener, çam, fırın,
  rüzgâr gülü, ay ışığı, buluşma taşı.
- `IslandArtwork`: deniz + ada + kazanılmış nesneler. Atlasın kaynak
  hücreleri ayrı dosyalara bölünmeden kırpılır; nesnelerin yeri sabittir.
- `IslandScene`: mevcut `IslandState` için sunum adaptörü.
- `IslandFrame`: diğer dekoratif önizlemelerde de aynı temel çizimi kullanır.
  Hesaba bağlı kazanımlar ana sayfa ve Adan ekranında gösterilir.

Ateş dekorasyondur, ödül değildir. Öğeleri istemci kazanmaz. Sessiz günler
yalnız deniz boyasını değiştirir; nesneler kaybolmaz. Animasyon, oyun motoru,
yeni paket veya yeni sunucu yazma işlemi eklenmedi.

Gece için üretilen ayrı görsel gerçek alfa içermediği için kullanılmadı.
Bu sürüm, ada ve nesnelere botanik renk matrisi uygular; ay ışığı parlak
kalır. Bağımsız gece illüstrasyonu bu sürümün teslimatı değildir.

## Kaynak ve üretim

Yerleşik imagegen aracı kullanıldı; CLI/API kullanılmadı. Kaynak:
`/Users/ebrarsismen/Desktop/Codex Görseli 14 Eyl 2026 17_39_53.png`.
Seçilen iki PNG, alfa korunarak `cwebp -q 88 -m 6` ile WebP'ye kodlandı.
Gerçek alfa içermeyen atlas denemeleri projeye alınmadı.

Ada üretim istemi (tam metin):

> Use case: background-extraction. Edit target: attached island artwork. Create a production transparent PNG asset for ILND wellness app. Preserve the exact main island silhouette, isometric camera, grassy open surface, rocks, plants and tiny central campfire, painterly brush texture. Remove ALL ocean, all detached offshore rocks, all ripples and shadows outside main island, replace with genuine transparent alpha. Main island centered fully visible with 4% transparent margin in landscape 3:2 canvas. Adjust grass slightly toward muted sage olive, rocks warm paper beige, soften contrast subtly to fit paper #F6F5F1 / forest #13763E brand. No extra objects or lettering. Keep the central fire small. Output one isolated main island, no background, not a checkerboard picture.

Seçilen atlas üretim istemi (tam metin):

> Create a transparent-background game asset PNG (actual alpha channel). Six isolated hand-painted isometric objects, arranged in a precise 3-column 2-row sprite atlas 1536x1024. No background at all. NO CHECKERBOARD. Objects centered inside equal cells with margins. Top row: small wooden glowing lantern; olive sage pine tree; beige clay bread oven. Bottom row: wooden wind pennant with terracotta cloth; ivory crescent moon with two stars; three smooth gathering stones. Muted warm paper beige and sage colors, soft painterly faceted shapes, cozy island wellness style, sunlight from top left. All six objects entirely separated, transparent space around each. Output RGBA with clear empty pixels, no grey squares no white background.

## Doğrulama ve performans sınırı

İki WebP toplam yaklaşık 342 KiB. Ada için 768 / 1536 px olmak üzere iki
çözme boyutu, atlas için ortak 768 px ImageCache kaydı kullanılır.
Sahne tek RepaintBoundary içindedir. Gece matrisi ek çizim maliyeti taşıyabilir;
bu sürümde gerçek cihaz profil ölçümü yapılmadı, FPS/bellek iyileşmesi iddiası yok.

Widget kontrolleri: boş/kısmi/tam ada, sessiz günlerde kazanım korunması,
gece, TR/EN yükleme/hata/veri durumları, ana sayfa kazanımları ve gezinme,
dar ekran ve büyük metin. Önizlemeler `build/island-preview/` altında.

Yayın öncesi fiziksel cihazda profile modunda soğuk açılış, tema geçişi,
kaydırma, image cache ve raster süreleri önceki sürümle karşılaştırılmalı.

## Kullanıcının ada ismi

Adan ekranındaki “adana isim ver / ismi değiştir” eylemi 1–32 karakterlik
bir isim kabul eder. İsim `users/{uid}/preferences/island.name` alanında
saklanır ve ana sayfa ile ada ekranında ortak kullanılır. Baş/son boşluklar
silinir, yinelenen boşluklar birleştirilir. İsim konmamışsa önceki sahiplik
başlığı görünür. Kayıt hatasında taslak korunur ve yeniden denenebilir.

Bu belge mevcut kullanıcıya özel Firestore kuralı kapsamındadır; kazanımları
tutan `island/{uid}` kaydı hâlâ salt okunurdur. Hesap anahtarlı dinleyici ve
kayıt koruması başka hesabın adının görüntülenmesini/yazılmasını önler.
Testlerde bellek deposu kullanılır; canlı hesapla cihazlar arası kayıt testi
yapılmamıştır. Yeni kural veya sunucu dağıtımı gerektiren şema eklenmedi.
