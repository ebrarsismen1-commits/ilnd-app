# ilnd — Design System (tek kaynak)

Kod karşılığı: `core/theme/` (palette+colors+text_styles+theme) · UI işi yaparken
`ui` skill bu belgeye uyar. Estetik gerekçeler: docs/ilnd_tasarim_vizyonu.md §1-3, §8.

## 1. Renk (pano-kalibre, kod ile birebir)
| Token | Gündüz | Gece (botanik) | Kullanım |
|---|---|---|---|
| base | #F5F4F1 | #10120F | zemin |
| surface / strong | #FFFFFF / #EBE8E1 | α-beyaz / #1C211C | kart / dolgu |
| text / muted | #111827 / #6B7280 | #F1F3EF / #9AA39A | metin |
| border | #E3E0D8 | α-beyaz %16 | 0.5px hairline |
| **accent** | **#1F9D57** | **#34C77A** | marka, CTA, aktif |
| accentSoft | #DCF3E4 | #1E3A2A | seçili dolgu, halka zemini |
| amber (pop) | #E2611C | #F2794A | enerji anı, niyet, kutlama |
Kural: yeni hex önce palete girer; gece = yeşile çalan koyular, nötr gri YASAK.
Pano ek tonları (editoryal kartlar): deep #274D33 · matcha #9BAA6F · krem #EFEBDD.

## 2. Tipografi
| Rol | Font | Kural |
|---|---|---|
| Display/başlık | Noto Serif | sıkı aralık (−%2/em); **italik kelime vurgusu imzadır** ("uyku *ritüeli*") |
| Gövde | DM Sans 400/500 | 13-16px, lh 1.4-1.5 |
| Etiket | DM Sans 500 CAPS | 9-11px, tracking 1-2px, az kullan |
| Sayı/istatistik | IBM Plex Mono | makro, streak, saat |

## 3. Boşluk & Şekil
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
Pressable · Entrance · AnimatedBackground · CoverImage(+editoryal filtre) ·
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
