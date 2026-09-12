# ADR-0008: "Ada" tasarım dili (kart düzeni, kağıt palet, ada yüzeyi)

**Status:** Accepted
**Date:** 2026-09-12

## Decision
Uygulamanın görsel dili Figma'daki "Ada" tasarımına geçti (dosya
`dMUmZ7PzUFYem6LJeS9lPG`, Page 2): Kâğıt zemin + Mürekkep metin + Orman
vurgu, yumuşak Adaçayı/Su/Kil yüzeyler, 1px kenarlıklı kartlar, serif
Regular başlıklar ve her ekranın merkezinde kullanıcının adası.

## Context
Ekranlar 2026-08 handoff'una göre "kutusuz" çizilmişti: bölümleri yalnız
0.5px hairline ve boşluk ayırıyordu (DESIGN_SYSTEM §3, §7.1). Owner yeni
tasarımı (Page 2) getirdi ve "kalan ekranları güncelle" dedi. Yeni tasarım
tam tersini söylüyor: içerik kartlarda yaşıyor, kartın kenarlığı var,
başlıklar kalın değil Regular, ve ada illüstrasyonu ekranın kahramanı.

İki dil aynı anda yaşayamaz: yarısı kartlı yarısı hairline bir uygulama
"jenerikleşme"den daha kötü, tutarsız görünür (PROJECT_PRINCIPLES #6, #8).

## Alternatives
1. **Yalnız renkleri güncelle, düzeni koru.** Ucuz ama tasarımın kendisi
   düzen hakkında: kart, ada kartı, hap seçenek. Renk tek başına ekranları
   tasarıma yaklaştırmıyordu.
2. **Tasarımı birebir, metinler dahil uygula.** Tasarımın metinleri "örnek
   veri" olarak işaretli ve cümle düzeni kullanıyor; ev üslubu (küçük harf
   butonlar, "günlük" başlığı) testlerle kilitli owner kararları.
   Uygulasaydık kilitli kararları sessizce iptal etmiş olurduk.
3. **Seçilen:** görsel dili birebir uygula (renk, ölçü, bileşen, yerleşim),
   metin kurallarını koru, yeni metinleri ev üslubunda yaz.

## Pros / Cons
+ Tek bir dil: paletten bileşene kadar tasarımla birebir.
+ Ortak bileşenler (`core/widgets/ilnd_surfaces.dart`) altı ekranda tekrar
  eden kart/satır/hap/başlık desenini tek kaynağa aldı.
+ Ada yüzeyi tek widget'a (`IslandFrame`) indi: illüstrasyon geldiğinde
  Bugün, Adan, Karşılama, Topluluk ve Odaklan birlikte değişir.
− DESIGN_SYSTEM §3 ve §7.1'in "kutu hastalığı yasak" kuralı tersine döndü;
  belge güncellendi ama eski ekran kodunda kalan hairline desenleri bir
  süre yan yana yaşayacak.
− Metin üslubu ile tasarım arasındaki fark (küçük harf / cümle düzeni)
  duruyor; owner kararı bekliyor.
− Statik kesimler elle üretilen çıktı: Lora yükseltilirse `fonttools
  varLib.instancer wght=400/600` adımı tekrarlanmalı (pubspec'te not var).

## Reason
Tasarım, ürünün kendi sahibinden geliyor ve düzen kararlarını içeriyor.
Yarım uygulama (yalnız renk) hem tasarımı hem mevcut dili bozardı.

## Consequences
- Yeni renk yine yalnız `AppPalette`'e girer; `sea`, `sky`, `clay` eklendi.
- Kart köşesi 16, kontrol 14, ana görsel 24; kenarlık 1px. Yeni ekran bu
  üç değerin dışına çıkamaz (`AppSpacing`).
- Serif başlıklar Lora Regular. Lora 2026-09-12'de pakete gömüldü, Noto
  Serif kaldırıldı; statik kesimler değişken fonttan üretiliyor ve OFL
  metni uygulamanın lisans ekranında kayıtlı.
- Ada illüstrasyonu ŞİMDİLİK YOK (owner: "ada çizimlerini şimdilik boş
  bırak"). `IslandFrame` yalnız gökyüzü + deniz iki tonunu çizer;
  `IslandPainter` kodda duruyor ama hiçbir ekran çağırmıyor.
- Her ekran yedi cihaz ölçüsünde taşma testine tabi
  (`test/core/ada_layout_test.dart`).

## Future Impact
İllüstrasyonlar geldiğinde tek dokunulacak yer `IslandFrame`'in arka planı.
Tasarım bir daha bu ölçüde değişirse maliyet yine yüksek olur: ekran başına
yerleşim, ortak bileşenlerin ölçüleri ve bu ADR birlikte güncellenmeli.
