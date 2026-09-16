# ADR-0010: Kademeli geri bildirim ve Kişisel Durum sözleşmesi

**Status:** Accepted (yalnız sözleşme; uygulama ayrı onay ister)
**Date:** 2026-09-16

## Decision
ILND kullanıcıya üç ayrı kanıt seviyesinde konuşur: **Yansıtma** (Seviye 1),
**Kişisel Durum** (Seviye 2) ve **Kişisel Örüntü** (Seviye 3). Seviye 1 ve 2
tek değişkenli, deterministik, şablonla yazılan ve istatistik testi
gerektirmeyen betimlemelerdir; Seviye 3'ten bağımsız olarak geliştirilip
yayınlanabilir. Seviye 3 yalnız ayrı bir istatistik protokolüyle (ADR-0011,
henüz yok) konuşabilir. Bu ADR Pattern Engine algoritmasını DONDURMAZ.

## Context
ADR-0009'daki V0.1 P5 motoru önceden kayıtlı istatistik kapısını geçemedi
(yanlış pozitif, tekrarlı bakış). Daha muhafazakâr bir Pattern Engine,
gerçek bir örüntüyü en erken ~6–8 haftada gösterebilecek. Kullanıcı bu süre
boyunca değer almalı; ama betimleyici bir istatistik asla "keşfedilmiş örüntü"
gibi sunulmamalı. Bu ADR, kanıt miktarı arttıkça ILND'nin söylediklerinin
dürüstçe artmasını sağlayan ürün ve veri sözleşmesini dondurur.

Owner kararları: 2026-09-16.

## Frozen contract

### 1. Sayım terimleri (birbirinin yerine kullanılmaz)

| Terim | Tanım | Kullanım |
|---|---|---|
| Takvim gecesi | Bir `nightKey` (akşamın yerel tarihi); kayıt olsun olmasın | Pencereler, geçmiş süresi, tazelik |
| Kayıtlı akşam | Geçerli akşam ruh hali olan gece (`invalid_time` değil; seyahat gecesi dahil) | Ruh hali bölümü (Seviye 1–2) |
| Kayıtlı sabah | Geçerli sabah enerjisi olan gece (aynı kurallar) | Enerji bölümü (Seviye 1–2) |
| Eşleşmiş gece | İki tarafı geçerli ve seyahat gecesi olmayan gece | YALNIZ Seviye 3 |

"Eşleşmiş gece" kullanıcıya gösterilmez ve Seviye 1–2'nin hiçbir kuralında
kullanılmaz. Gece anahtarı, saat penceresi ve `tzShift` tanımları ADR-0009
§2'deki gibidir.

### 2. Seviyeler

| | Seviye 1: Yansıtma | Seviye 2: Kişisel Durum | Seviye 3: Kişisel Örüntü |
|---|---|---|---|
| İçerik | Girilen değer(ler) | Tek değişkenin adı konmuş bir dönemdeki bandı, aralığı, sayımı ve olağana göre farkı | İki değişken arasında doğrulanmış eşleşme |
| Hesap | yok (gösterme, listeleme) | ortalama → bant, min/max, sayım, dönem farkı | ADR-0011 |
| İstatistik testi | yok | yok | var |
| Dil | "kaydettin", "son 3 sabahın" | geçmiş zaman, dönemle sınırlı | ADR-0011 şablonları + "kesin bir açıklama değil" |
| Yasak | ortalama, eğilim, karşılaştırma | iki değişkeni birleştirmek, "ardından", "olunca", neden, gelecek, "seni tanıyorum" | nedensellik, tahmin, tıbbi dil |

**Ayrım kuralı:** Seviye 1 ve 2'de akşam ruh hali ile sabah enerjisi aynı
cümlede ya da bağlaçla yan yana yer almaz. Seviye 2 hesaplarında iki değişken
aynı fonksiyonda kullanılmaz.

### 3. Bağımsız değişkenler
Ruh hali bölümü yalnız kayıtlı akşamlardan, enerji bölümü yalnız kayıtlı
sabahlardan hesaplanır. Seviye 1–2 eşleşmiş gece gerektirmez. Seyahat gecesi
Seviye 2'ye dahil, Seviye 3'e hariçtir.

### 4. Bant sözleşmesi (1–5)
- Ölçek değerleri: tam sayı 1..5.
- Bir ortalama `m` için: `|m − (k + 0.5)| ≤ 0.15` (k ∈ 1..4) ise bant `"k_k+1"`
  ("A ile B arası"); değilse bant `round(m)` (`"1"`..`"5"`).
- Arayüzde ondalık sayı gösterilmez.
- Sayısal bant sözleşmesi dondurulmuştur. Kullanıcıya gösterilen Türkçe ve
  İngilizce sıfatlar (ör. enerji=1 için "tükenmiş") dondurulmamıştır; metin
  incelemesinde bu sözleşme değişmeden güncellenebilir.

### 5. Kilometre taşları (değişken başına)
Tüm pencereler `asOfNight` dahil geriye doğru takvim gecesidir.
`asOfNight` = herhangi bir tarafı geçerli olan en son `nightKey` (sunucu
saati kullanılmaz).

| Aşama | Açılma koşulu | Hesap |
|---|---|---|
| Yansıtma | Az önce girilen değer | yok |
| Son kayıtlar | ≥1 kayıt ve üst aşamalar açılmamış | Son ≤6 değerin listesi |
| Haftan | Son 7 gecede ≥5 kayıt | ortalama → bant, min, max, sayım |
| Son 14 gecen | İlk geçerli kayıt ≥14 takvim gecesi önce **ve** son 14 gecede ≥9 kayıt | ortalama → bant; kovalar: düşük 1–2, orta 3, yüksek 4–5; sayım |
| Olağanın | İlk geçerli kayıt ≥28 takvim gecesi önce **ve** son 28 gecede ≥10 kayıt | ortalama → bant |
| Olağana göre | "Olağanın" açık **ve** son 7 gecede ≥5 **ve** önceki 21 gecede (`asOfNight − 27 … asOfNight − 7`) ≥10 kayıt | Bkz. §6 |

Her bölümde yalnız açılmış en üst aşama gösterilir: Olağanın (+ olağana
göre) → Son 14 gecen → Haftan → Son kayıtlar. "Olağana göre" bir baseline
yoksa asla açılmaz.

**Son 14 gecen olağan DEĞİLDİR.** "olağan", "genelde", "tipik" dili, yön,
eğilim ya da karşılaştırma içeremez.

**Kova kuralı:** Düşük/orta/yüksek kovaları yalnız betimleme içindir. Kendi
ADR'ında ayrıca tanımlanmadıkça Pattern Engine tarafından kullanılamaz.

### 6. Olağana göre karşılaştırma
`R` = son 7 gecenin ortalaması, `P` = önceki 21 gecenin ortalaması,
`Δ = R − P`. Öncelik sırasıyla:

| Durum | Koşul |
|---|---|
| `insufficient` | §5'teki kayıt ya da geçmiş koşulları sağlanmıyor |
| `higher` / `lower` | `Δ ≥ +0.5` / `Δ ≤ −0.5` |
| `mixed` | `|Δ| < 0.5` ve son 7 gecede hem ≤2 hem ≥4 değer var |
| `stable` | `|Δ| < 0.25` |
| `none` | `0.25 ≤ |Δ| < 0.5` (yön söylenmez) |

0.5 yarım kategori, 0.25 çeyrek kategoridir. Bunlar ürün eşikleridir;
anlamlılık testi değildir ve kullanıcıya daha çok kart göstermek için
değiştirilmez. Metin geçmiş zamanlı ve dönemle sınırlıdır ("Son 7 gecende
… daha yüksekti"); "artıyor", "düzeliyor" gibi şimdiki zaman kullanılmaz.

Değişkenlik etiketi (sd tabanlı "dengeli/değişken") V0'da kullanılmaz.

### 7. Tazelik (ürün kuralı, istatistik eşiği değil)
Cihazın yerel bugünü ile `asOfNight` arasında 3'ten fazla takvim gecesi varsa
etkin Seviye 2 yorumları gizlenir ve nötr dönüş durumu gösterilir. Karar
istemcidedir. Bu kural verinin güncelliğiyle ilgili bir ürün kararıdır;
istatistiksel bir güven eşiği değildir.

### 8. Hesaplama sözleşmesi
- Seviye 1 istemcide, girilen değerden anında üretilir.
- Seviye 2 sunucuda (Cloud Function) üretilir ve `users/{uid}/intel/state`
  dokümanına yazılır. İstemci bu dokümanı yazamaz.
- Tetikleyici `users/{uid}/nights/{nightKey}` yazımıdır. Önce olay içeriğinin
  eski ve yeni hâli karşılaştırılır (okuma yok):

| Olay | İş |
|---|---|
| Yalnız akşam değeri eklendi ya da değişti | Yalnız ruh hali bölümü |
| Yalnız sabah değeri eklendi ya da değişti | Yalnız enerji bölümü |
| İkisi de değişti | İki bölüm |
| Değer değişmedi | Hiçbir iş (0 okuma) |
| Bir tarafın hiç gelmemesi | Olay yok; o değişkenin sayımında eksik kalır |
| Doküman silindi | Rıza geri alındıysa hesap yok; TTL silmesinde etkilenen bölümler |

- Bir hesap en fazla: rıza (1) + state (1) + son 28 gece (≤28) okur, state'i
  en fazla bir kez yazar ve girdi hash'i değişmediyse yazmaz.
- Geçmiş süresi kuralı için state `firstEveningNight` ve `firstMorningNight`
  alanlarını tutar.
- Eşleşmiş gece sayımı ve Seviye 3 hesabının ne zaman, nasıl yapılacağı
  ADR-0011'e aittir.

State'in Seviye 2 bölümü (alan adları uygulamada değişebilir, anlamı değişmez):
```
{ engineVersion, asOfNight, inputHash,
  mood:   { stage, lastValues[], week{n,band,min,max}|null,
            days14{n,band,low,mid,high}|null, usual{n,band}|null, change },
  energy: { … aynı yapı … },
  firstEveningNight, firstMorningNight }
```
Ham ortalama, standart sapma ya da iç istatistik istemciye açılmaz.

### 9. Şablon zorunluluğu ve LLM yok
Seviye 1 ve 2'nin tüm kullanıcı metni deterministik `.arb` şablonlarından
gelir. Anthropic ya da başka bir LLM çağrılmaz. Claude bant, eğilim, güven,
örüntü, anlamlılık, tahmin ya da doğruluk hesaplayamaz. Seviye 3 metni de
şablonla gösterilebilir olmalıdır; bir dil katmanı ileride yalnız isteğe bağlı
olabilir.

### 10. Tek evrilen kart
- Tek bir "Kayıtların" kartı. İçinde birbirinden bağımsız "Akşamların" ve
  "Sabahların" bölümleri; her bölüm kendi aşama etiketini taşır ("bugün",
  "son kayıtlar", "son 7 gece", "son 14 gece", "olağanın").
- Bölümler arasında bağlaç, ok ya da bağ çağrıştıran görsel yok.
- Seviye 3 içeriği (onaylı örüntü ya da tek seferlik `not_observed`) kartın
  üstüne eklenir; Seviye 2 bölümlerini kaldırmaz. `not_observed` bir kez
  gösterilir, ardından kart normal Kişisel Durum'a döner.
- Seviye 3 aday durumu kartın hiçbir yerine (metin, ilerleme, zamanlama,
  görünüm, bildirim, analitik) sızmaz; aday olan ve olmayan kullanıcı aynı
  kartı görür.
- V0'da örüntü bildirimi yoktur.
- Rozet, puan, yüzde ve oyunlaştırma yoktur.

### 11. Seviye 2 → Seviye 3 sınırı
Seviye 2 şunu söyleyebilir: "Son 7 gecende sabah enerjin olağanına göre daha
yüksekti." Bu, tek bir değişkenin adı konmuş bir geçmiş dönemdeki
aritmetik betimlemesidir; kullanıcı kayıtlarından doğrulayabilir.

Seviye 2 şunu söyleyemez: "Daha iyi akşamlar daha yüksek sabah enerjisine
yol açıyor" ya da "… günlerin ardından … genellikle". Bu, iki değişken
arasında geceler boyunca tekrar eden bir düzenlilik iddiasıdır; rastgele
veride de oluşabilir ve hata kontrolü gerektirir (ADR-0009 sonucu). Bu tür
her cümle yalnız ADR-0011 kapısından geçebilir.

### 12. Gizlilik ve veri minimizasyonu
- Yalnız akşam ruh hali (1–5) ve sabah enerjisi (1–5). Stres, uyku, hareket,
  öğün, günlük metni, alışkanlık, su ve kilo bu sözleşmenin kapsamı dışında.
- Tek ve açık bir rıza: saklama + betimleyici özetler + örüntü analizi.
  Rıza yoksa değerler sunucuya yazılmaz; Seviye 1 cihazda çalışır.
- Rıza geri alınınca ham geceler ve türetilmiş durum silinir; yalnız asgari
  rıza geri alma kaydı kalır.
- Ham kayıt saklama süresi 180 gün.
- Check-in değerleri `IlndMemory`'ye yazılmaz, Claude bağlamına gitmez.
- Check-in değerleri analitik ya da hata raporlarına gönderilmez.
- Hesap silme `users/{uid}` ağacını kapsar.
- Rıza metni, 180 gün ve özel nitelikli veri değerlendirmesi hukuk/KVKK
  görüşüne tabidir.

## Alternatives
1. **Örüntü doğrulanana kadar hiçbir şey göstermemek.** 6–8 hafta değersiz
   bir deneyim; elendi.
2. **Erken dönemde örüntü dili kullanmak** ("fark etmeye başladım").
   Betimlemeyi keşif gibi sunar; V0.1'in yanlış pozitif sorununu kullanıcıya
   taşır. Elendi.
3. **Seviye 2'yi eşleşmiş gecelere bağlamak.** Yalnız akşam ya da yalnız
   sabah giren kullanıcıyı cezalandırır; elendi.
4. **14 gecelik ortalamaya "olağan" demek.** Yerleşmiş olmayan bir değeri
   baseline gibi sunar; elendi.

## Pros / Cons
+ Kullanıcı ilk kayıttan itibaren dürüst bir değer alır
+ Örüntü iddiası nadir ve anlamlı kalır
+ Yeni altyapı ve LLM maliyeti yok
− Seviye 2 zamanla tekrarlayıcı hissettirebilir
− Kullanıcı iki ayrı bölümden kendisi bir ilişki çıkarabilir
− Sabah başına ~30 okuma; ileride optimizasyon gerekebilir

## Reason
Kanıtın gücü ile söylenenin gücü eşleşmeli. Betimleme erken ve sık,
ilişki geç ve nadir olmalı.

## Consequences
- Seviye 1–2 uygulaması bu ADR'a göre ayrı onayla başlayabilir.
- Seviye 3 uygulaması ADR-0011 dondurulup onaylanmadan başlayamaz.
- ADR-0009'daki V0.1 baseline tanımı (`computeBaseline`: 28 gece, en az 7,
  seyahat hariç) Seviye 2 için bu ADR ile geçersizdir; ADR-0009 FAIL kaydı
  olarak kalır.
- Bu sözleşmedeki bir sayı, pencere ya da aşama koşulu değişirse yeni ADR
  revizyonu gerekir.

## Açık konular (bu ADR'ı dondurmaya engel değil)
- **Ana sayfa öneri eşlemesi:** `_MoodCheckIn` değiştirilmeden önce ayrı bir
  entegrasyon kararı olarak çözülecek. Bu ADR onu değiştirmez.
- **Commit'lenmemiş `home_screen.dart` çalışması** (başka bir oturum)
  olduğu gibi korunur; entegrasyon sırası o iş netleşince belirlenir.
- **Hukuk/KVKK görüşü:** rıza metni, 180 gün, özel nitelikli veri, rıza
  kaydının saklanması. Yayından önce gerekli.
- **Kullanıcıya gösterilen sıfatlar:** metin incelemesinde güncellenebilir.
- **ADR-0011'e ait ve çözülmemiş:** sıralı P5, dönem, kontrol noktaları, α
  harcaması, etki eşiği, otokorelasyon politikası, `few_variation`,
  zayıflama, simülasyon kapıları ve **tekrarlanan dönemlerde kullanıcı ömrü
  boyunca yanlış pozitif politikası.** "Dönem başına ≤%2,5" tek başına yeterli
  bir ömür boyu kontrol olarak bu ADR'da kabul EDİLMEMİŞTİR.

## Future Impact
Yeni bir değişken eklenirse aynı üç seviye sözleşmesiyle, önce Seviye 1–2
olarak eklenir. Okuma maliyeti büyürse state içinde değişken başına kompakt
28 gecelik dizi tutulabilir; sözleşme değişmez.
