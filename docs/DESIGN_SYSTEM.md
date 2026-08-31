# ilnd — Design System (tek kaynak)

Kod karşılığı: `core/theme/` (palette+colors+text_styles+theme) · UI işi yaparken
`ui` skill bu belgeye uyar. Estetik gerekçeler: docs/ilnd_tasarim_vizyonu.md §1-3, §8.

## 1. Renk (pano-kalibre, kod ile birebir)
| Token | Gündüz | Gece (botanik) | Kullanım |
|---|---|---|---|
| base | #F5F4F1 | #10120F | zemin |
| surface / strong | #FFFFFF / #EBE8E1 | α-beyaz / #1C211C | kart / dolgu |
| text / muted | #111827 / #5F6875 | #F1F3EF / #9AA39A | metin |
| border | #E3E0D8 | α-beyaz %16 | 0.5px hairline |
| **accent** | **#13763E** | **#34C77A** | marka, CTA, aktif |
| accentSoft | #DCF3E4 | #1E3A2A | seçili dolgu, halka zemini |
| amber (pop) | #A84711 | #F2794A | enerji anı, niyet, kutlama |
| danger | #A54A40 | #DA8578 | hata, yıkıcı eylem |
| water | #2E86B8 | #93D5FF | su ilerlemesi |
Kural: yeni hex önce palete girer; gece = yeşile çalan koyular, nötr gri YASAK.
Kural: her yeni/değişen renk WCAG AA'yı geçmeli (metin 4.5:1, ikon-çubuk 3:1);
test/core/contrast_test.dart kilitler. Gündüz tonları 2026-08-24'te bir tık
koyulaştı: eski değerlerle (#1F9D57 / #E2611C) beyaz metinli birincil buton
3.49:1 idi. Gece paleti zaten geçiyordu, dokunulmadı.
Pano ek tonları (editoryal kartlar): deep #274D33 · matcha #9BAA6F · krem #EFEBDD.

## 2. Tipografi
| Rol | Font | Kural |
|---|---|---|
| Display/başlık | Noto Serif | sıkı aralık (−%2/em); **italik kelime vurgusu imzadır** ("uyku *ritüeli*") |
| Gövde | DM Sans 400/500 | 13-16px, lh 1.4-1.5 |
| Etiket | DM Sans 500 CAPS | 9-11px, tracking 1-2px, az kullan |
| Sayı/istatistik | DM Mono 500 | makro, streak, saat |

Üç aile de **pakete gömülüdür** (`assets/fonts/`, pubspec `fonts:` bölümü),
hiçbiri çalışma anında indirilmez. İndirilen font ağsız ilk açılışta sistem
fontuna düşer: uygulama açılır, hata görünmez, sadece kimliği kaybolur.

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
**Ayrım kutuyla değil boşlukla kurulur** (2026-08-19 editoryal geçiş): içerik
kartı yok; bölümleri 0.5px hairline + boşluk + tipografi ayırır. Kenarlık
yalnız işlevselse kalır (buton, giriş alanı, paylaşım kartı, kilitli öğe çipi).
Her ekranda TEK büyük an olur — ölçek zıtlığı (§7.2) bir süs değil, "önce şuna
bak" demenin yolu.

**Emoji yasak.** İkon gerekiyorsa `Icons.*`, sembol gerekiyorsa tek renkli
geometrik glif (mood glifleri ☾ ◍ ◐ ✦ ☁ bu yüzden kalır). Yasak
test/core/no_emoji_test.dart ile kilitli.

**Zeminde animasyon yok.** Ekran zemini düz renktir (`p.base`); hareketli aura
degradesi 2026-08-19'da kaldırıldı. Fotoğraf üzerindeki karartma gradyanları
işlevseldir (metin okunabilirliği), onlar kalır.

8pt grid (`AppSpacing.unit`) · ekran pad 20 · kart radius 16 · input/buton radius 12
· buton yüksekliği 52 · tap hedefi ≥44. Gölge yalnız 2 yerde: merkez halka + modal.

## 4. Motion — dil: "nefes"
| Token | Değer | Nerede |
|---|---|---|
| breathe | 4sn genişle / 6sn daral, easeInOut | halka, splash, yükleme |
| settle | ~320ms easeOut | seçim onayı, kart giriş (Entrance 550ms/stagger 80ms) |
| pop | ~220ms hafif overshoot | tab, mood seçimi |
Yeni süre/eğri icat edilmez; sayfa geçişi = mevcut fade-up.

## 5. Bileşen Envanteri (önce bunları kullan, sonra icat et)
Pressable · Entrance · CoverImage(+editoryal filtre) ·
EditorialGradient · Shimmer · IlndToast · AuthInputField · SocialSignInButton ·
AuthDivider. Yeni bileşen = 2+ yerde kullanım kanıtı → core/widgets'a.

## 6. Ses Tonu (UI metni)
küçük harf başlıklar ("keşfet.") · sıcak, kısa, buyurmayan · suçluluk dili yasak
(streak: "7 gündür kendine alan açıyorsun") · boş durum = davet, özür değil ·
her metin tr+en .arb'de.

## 7. Editoryal Yasalar (ölü-görünüm panzehiri, vizyon §Pano)
1. Kutu hastalığı yasak — bölümleri boşluk+tipografi ayırır
2. Ekranın TEK büyük anı olur (ölçek zıtlığı)
3. Renk fotoğraftan gelir; fotoğraf zemin olabilir, süs olamaz
4. Halka markanın jestidir: tap=konuş, bas-tut=nefes; durumları vizyon §Halka Anatomisi
