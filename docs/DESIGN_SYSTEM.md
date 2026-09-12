# ilnd — Design System (tek kaynak)

Kod karşılığı: `core/theme/` (palette+colors+text_styles+theme) · UI işi yaparken
`ui` skill bu belgeye uyar. Estetik gerekçeler: docs/ilnd_tasarim_vizyonu.md §1-3, §8.

## 1. Renk (Ada tasarımı, kod ile birebir · ADR-0008)
| Token | Gündüz | Gece (botanik) | Kullanım |
|---|---|---|---|
| base | #F6F5F1 (Kâğıt) | #10120F | zemin |
| surface / strong | #FCFCF8 / #E9EDDF (Adaçayı) | α-beyaz / #1C211C | kart / yumuşak kart |
| text / muted | #22382E (Mürekkep) / #59675E | #F1F3EF / #9AA39A | metin |
| border | #DDDFD6 | α-beyaz %16 | 1px kart kenarlığı |
| **accent** | **#13763E** (Orman) | **#34C77A** | marka, CTA, aktif |
| accentSoft | #E1EEDF | #1E3A2A | aktif sekme hapı, halka zemini |
| amber (pop) | #A84711 | #F2794A | enerji anı, niyet, kutlama |
| danger | #A54A40 | #DA8578 | hata, yıkıcı eylem |
| water | #2B7DAB | #93D5FF | su ilerlemesi |
| sea / sky | #DCECE7 (Su) / #E6EEDE | #16211E / #1A2119 | ada kartı, ILND+ kartı |
| clay | #ECD1C5 (Kil) | #2A211D | sıcak vurgu zemini |
Kural: yeni hex önce palete girer; gece = yeşile çalan koyular, nötr gri YASAK.
Kural: her yeni/değişen renk WCAG AA'yı geçmeli (metin 4.5:1, ikon-çubuk 3:1);
test/core/contrast_test.dart kilitler. Gündüz tonları 2026-08-24'te bir tık
koyulaştı: eski değerlerle (#1F9D57 / #E2611C) beyaz metinli birincil buton
3.49:1 idi. Gece paleti zaten geçiyordu, dokunulmadı.
Pano ek tonları (editoryal kartlar): deep #274D33 · matcha #9BAA6F · krem #EFEBDD.

## 2. Tipografi
| Rol | Font | Kural |
|---|---|---|
| Display/başlık | Lora **Regular** | sıkı aralık (−%2/em); **italik kelime vurgusu imzadır** ("uyku *ritüeli*") |
| Gövde | DM Sans 400/500 | 13-16px, lh 1.4-1.5 |
| Etiket | DM Sans 500 CAPS | 9-11px, tracking 1-2px, az kullan |
| Sayı/istatistik | DM Mono 500 | makro, streak, saat |

Üç aile de **pakete gömülüdür** (`assets/fonts/`, pubspec `fonts:` bölümü),
hiçbiri çalışma anında indirilmez. İndirilen font ağsız ilk açılışta sistem
fontuna düşer: uygulama açılır, hata görünmez, sadece kimliği kaybolur.

Başlık fontu **Lora** (2026-09-12, owner onayı): Ada tasarımının kendi
fontu, Noto Serif'in yerini aldı ve ağırlık 600 → 400'e indi. Google Fonts
Lora'yı yalnız değişken kesim yayınlıyor; pakete giren 400/600 ve italik
400 statik kesimleri `fonttools varLib.instancer` ile üretildi. Değişken
dosyayı doğrudan gömmek "kod 600 der, ekran 400 çizer" tuzağıydı.
İtalik kesim ARTIK GERÇEK: Noto Serif'te italik dosya yoktu ve Flutter
eğik taklit çiziyordu. Lora OFL ile geliyor, lisans metni pakette
(`assets/fonts/Lora-OFL.txt`) ve uygulamanın lisans ekranında kayıtlı
(main.dart, LicenseRegistry).

DM Mono, DM Sans'ın kendi monospace kardeşidir; eşleşme IBM Plex Mono'dan
daha doğal. **En kalın kesimi 500'dür**, 600/700 üretilmemiş. Sayı stilleri
bu yüzden 500'e kırpılır (`AppTextStyles.monoMaxWeight`): aksi halde kod 700
der, ekran 500 çizerdi. Vurgu ağırlıktan değil boyuttan gelir.

Sayılarda monospace bir süs değil hizalama aracıdır: alt alta gelen makro
değerleri ve 999'dan 1000'e geçen sayaçlar satırı zıplatmamalı. DM Sans bunu
veremez, `tnum` (tabular rakam) özelliği yok; ölçüldü.

`lib/` içinde hiç `GoogleFonts` çağrısı yok ve
`test/core/typography_test.dart` hem bunu, hem dosyaların varlığını, hem de
gerçekten TrueType olduklarını kilitliyor.

## 3. Boşluk & Şekil
**İçerik kartta yaşar** (2026-09-12, ADR-0008): kağıt kart + 1px kenarlık,
ya da kenarlıksız renkli kart (Adaçayı / Su). Bölüm içi satırları hâlâ
0.5px hairline ayırır. Bir önceki dil ("kutu yok, yalnız hairline")
2026-08-19'dan 2026-09-12'ye kadar geçerliydi; tasarım tersine döndü.
Her ekranda TEK büyük an olur — ölçek zıtlığı (§7.2) bir süs değil, "önce şuna
bak" demenin yolu.

**Emoji yasak.** İkon gerekiyorsa `Icons.*`, sembol gerekiyorsa tek renkli
geometrik glif (mood glifleri ☾ ◍ ◐ ✦ ☁ bu yüzden kalır). Yasak
test/core/no_emoji_test.dart ile kilitli.

**Zeminde animasyon yok.** Ekran zemini düz renktir (`p.base`); hareketli aura
degradesi 2026-08-19'da kaldırıldı. Fotoğraf üzerindeki karartma gradyanları
işlevseldir (metin okunabilirliği), onlar kalır.

8pt grid (`AppSpacing.unit`) · ekran pad 20 · kart radius 16 · kontrol
(buton/giriş/öneri) radius 14 · ana görsel (ada kartı) radius 24 · buton
yüksekliği 52 · tap hedefi ≥44. Gölge YOK: ayrım kenarlık ve zeminle kurulur.

Her ekran yedi cihaz ölçüsünde (SE 320'den iPad 768'e) taşma testinden
geçer: `test/core/ada_layout_test.dart`. Sabit yükseklik veren her yeni
yüzey bu testin kapsamına girer.

## 4. Motion — dil: "nefes"
| Token | Değer | Nerede |
|---|---|---|
| breathe | 4sn genişle / 6sn daral, easeInOut | halka, splash, yükleme |
| settle | ~320ms easeOut | seçim onayı, kart giriş (Entrance 550ms/stagger 80ms) |
| pop | ~220ms hafif overshoot | tab, mood seçimi |
Yeni süre/eğri icat edilmez; sayfa geçişi = mevcut fade-up.

## 5. Bileşen Envanteri (önce bunları kullan, sonra icat et)
**Ada yüzeyleri** (`core/widgets/ilnd_surfaces.dart`): IlndCard ·
IlndIconTile · IlndListRow · IlndChip · IlndButton · IlndPageHeader ·
PracticeCard · IslandFrame.
**Diğerleri:** Pressable · Entrance · BreathRing · CoverImage(+editoryal
filtre) · EditorialGradient · Shimmer · IlndToast · AuthInputField ·
SocialSignInButton · AuthDivider.
Yeni bileşen = 2+ yerde kullanım kanıtı → core/widgets'a.

**Ada illüstrasyonu şimdilik yok** (owner, 2026-09-11): `IslandFrame`
gökyüzü + deniz iki tonunu çizer, üstüne başlık/hap/ilerleme oturur.
Çizimler geldiğinde tek dokunulacak yer bu widget'ın arka planıdır.

## 6. Ses Tonu (UI metni)
küçük harf başlıklar ("keşfet.") · sıcak, kısa, buyurmayan · suçluluk dili yasak
(streak: "7 gündür kendine alan açıyorsun") · boş durum = davet, özür değil ·
her metin tr+en .arb'de.

## 7. Editoryal Yasalar (ölü-görünüm panzehiri, vizyon §Pano)
1. Kart tek tip: kağıt + 1px kenarlık ya da renkli + kenarlıksız (ADR-0008)
2. Ekranın TEK büyük anı olur (ölçek zıtlığı)
3. Renk fotoğraftan gelir; fotoğraf zemin olabilir, süs olamaz
4. Halka markanın jestidir: tap=konuş, bas-tut=nefes; durumları vizyon §Halka Anatomisi
