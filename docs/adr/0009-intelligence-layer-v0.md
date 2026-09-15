# ADR-0009: Intelligence Layer V0 (tek örüntü, istatistik kapısı önce)

**Status:** Accepted (yalnız Commit 1–3: sözleşme, saf modüller, simülasyon kapısı)
**Date:** 2026-09-15

## Decision
ILND'nin ilk kendi hesapladığı çıkarım tek bir kişi içi eşleşmedir: zor geçen
akşamların (ruh hali 1–2) ertesi sabahındaki enerji, diğer sabahlardan
belirgin biçimde farklı mı (P5). Hesap deterministik, LLM içermez; kullanıcıya
gösterilmeden önce önceden kayda geçirilmiş bir simülasyon kapısını geçmek
zorundadır. Bu belgedeki sabitler ve kabul ölçütleri simülasyon sonucu
görülmeden DONDURULMUŞTUR; sonuca bakarak değiştirilmez.

## Context
Bugünkü "kişiselleştirme" cihazda tutulan metin hafızası ve Claude'un yazdığı
cümlelerden ibaret; hiçbir çıkarım ölçülmüyor. Hedef, küçük ama gerçek,
tekrar üretilebilir ve bize ait bir hesap. Tasarım 2026-09-14/15 oturumlarında
yapıldı ve owner tarafından yalnız istatistik kapısına kadar onaylandı.

Owner kararları (2026-09-15):
1. Sabah hatırlatması prensipte onaylı, V0'da UYGULANMAZ.
2. V0 check-in değerleri `IlndMemory`'ye yazılmaz, Claude bağlamına gitmez.
3. Rıza geri alınınca ham geceler ve türetilmiş durum silinir; yalnız asgari
   rıza geri alma kaydı kalır (hukuk görüşü bekliyor).
4. 14:00–16:59 arası soru sorulmaz.
5. `not_observed` durumu gösterilir.
6. Ana sayfa öneri eşlemesi DEĞİŞMEZ. V0 bunu gerektirirse durulur ve owner'a
   gerekçe sunulur (bkz. Açık konular).

Kapsam dışı (bu ADR ile yapılmaz): arayüz, rıza arayüzü, Firestore kuralları,
tetikleyici, deploy, TTL, P1–P4, Tomorrow Portrait, NBS, Claude, yeni altyapı.

## Frozen contract

### 1. Veri (gelecekteki `users/{uid}/nights/{nightKey}` dokümanının saf karşılığı)
Saf modüller Firestore'dan bağımsızdır; girdi olarak şu şekli alır:

```
night = {
  nightKey: "YYYY-MM-DD",                    // akşamın yerel tarihi
  evening?: { mood: 1..5, tzOffsetMin: -720..840, createdAtMs: number },
  morning?: { energy: 1..5, tzOffsetMin: -720..840, createdAtMs: number },
}
```

Geçersiz tip, aralık dışı değer ya da takvimde olmayan `nightKey` olan taraf
yok sayılır (hata fırlatılmaz).

### 2. Zaman eşleştirme
`L = createdAtMs + tzOffsetMin * 60000`, UTC alanlarıyla okunur.

- Akşam: `L.saat ∈ [17,24)` → `nightKey = tarih(L)`; `L.saat ∈ [0,4)` →
  `nightKey = tarih(L) − 1 gün`; diğer saatler → `invalid_time`.
- Sabah: `L.saat ∈ [4,14)` → `nightKey = tarih(L) − 1 gün`; diğer saatler →
  `invalid_time`.
- Türetilen anahtar dokümanın `nightKey`'ine eşit değilse → `invalid_time`.
- `invalid_time` taraf hiçbir hesaba girmez.

Saat dilimi kayması (`tzShift`), gece düzeyinde:
- Aynı gecenin iki geçerli tarafı arasında `|Δ offset| ≥ 120` → kayma.
- Referans: daha küçük `nightKey`'e sahip en son gecenin geçerli akşam
  offset'i, akşam geçersizse sabah offset'i. Bu gecenin ilk geçerli tarafı
  (akşam varsa akşam, yoksa sabah) ile referans arasında `|Δ| ≥ 120` → kayma.
- Kaymalı gecenin iki tarafı da baseline'a ve P5'e girmez. Yaz saati (60 dk)
  kayma değildir.

### 3. Pencereler
- `asOfNight` = en az bir geçerli tarafı olan en büyük `nightKey`. Yoksa
  hesap boş durum döner. Sunucu saati kullanılmaz; sonuç verinin saf
  fonksiyonudur.
- Baseline penceresi: `[asOfNight − 27 gün, asOfNight]`.
- P5 penceresi: `[asOfNight − 59 gün, asOfNight]`.

### 4. Baseline
`energyMean` = pencere içindeki, kaymasız gecelerin geçerli sabah
enerjilerinin aritmetik ortalaması. `energyN < 7` ise `null`. Akşam tarafı
gerekmez. Saklanan değer 1 ondalığa yuvarlanır; hesaplarda yuvarlanmamış
değer kullanılmaz (baseline P5'e girmez).

### 5. P5: `low_evening_mood_morning_energy`
- Eşleşmiş gece: P5 penceresinde, kaymasız, iki tarafı geçerli.
- LOW: `mood ≤ 2`. OTHER: `mood ≥ 3`. Eşik sabittir, kişiye göre değildir.
- `d = mean(energy | LOW) − mean(energy | OTHER)`.
- `sd` = tüm eşleşmiş gecelerin enerjisinin örneklem standart sapması (n−1).
- Karşılaştırmalarda `EPS = 1e-9` kullanılır (`d ≤ −0.5 + EPS` gibi).
- `halfStable`: geceler `nightKey`'e göre sıralanır, ilk `⌊N/2⌋` ve kalanı
  iki yarıdır. Her yarıda `nLow ≥ 3` ve `nOther ≥ 3` ise ve iki yarının
  `d`'si de `< 0` ise `true` (ters yön için ikisi de `> 0`).
- Permütasyon testi (iki yönlü): `B = 2000`; PRNG `mulberry32`; tohum
  `FNV-1a-32(uid + "|p5|" + setinSonGecesi + "|" + N)`, UTF-8. Bir index
  dizisi üzerinde kısmi Fisher–Yates ile her permütasyonda ilk `nLow` konum
  LOW grubudur (dizi permütasyonlar arasında sıfırlanmaz). `d*` ile
  `p = (1 + #{|d*| ≥ |d| − EPS}) / (B + 1)`.
- `p` yalnız `d ≤ −0.5` ya da `d ≥ +0.75` iken hesaplanır (yalnız bu
  durumlar p kullanır); aksi halde `null`. Sonucu değiştirmez, maliyeti düşürür.

### 6. Durumlar (yukarıdan aşağı ilk sağlanan)

| Durum | Koşul |
|---|---|
| `insufficient` | `N < 10` veya `nLow < 4` veya `nOther < 4` veya `sd < 0.5` |
| `strong` | `N ≥ 21`, `nLow ≥ 7`, `nOther ≥ 7`, `d ≤ −0.75`, `p < 0.05`, `halfStable` (negatif) |
| `opposite` | `N ≥ 21`, `nLow ≥ 7`, `nOther ≥ 7`, `d ≥ +0.75`, `p < 0.05`, `halfStable` (pozitif) |
| `emerging` | `N ≥ 14`, `nLow ≥ 5`, `nOther ≥ 5`, `d ≤ −0.5`, `p < 0.10` |
| `candidate` | `d ≤ −0.5`, `p < 0.20` |
| `not_observed` | `N ≥ 21`, `nLow ≥ 7`, `nOther ≥ 7`, `d > −0.5` |
| `inconclusive` | test edilebilir ama yukarıdakilerin hiçbiri değil |

`inconclusive`, onaylanan tasarımda adı konmamış boşluğu kapatır (ör. N=15,
d=−0.3). Kullanıcıya gösterilmez.

### 7. Gösterim durumu (`shownState`)
`S(N)` = penceredeki tüm eşleşmiş gecelerle durum. `S(N−1)` = aynı set, en
son eşleşmiş gece çıkarılarak (tohum, kalan setin son gecesi ve `N−1` ile).
`everShown` = önceki durumda `firstShownStrongNight` dolu.

1. `S(N) == strong` ve (`S(N−1) == strong` veya `everShown`) → `strong`
2. `everShown` ve `S(N) ∈ {emerging, candidate, inconclusive}` → `weakened`
3. `everShown` ve `S(N) ∈ {not_observed, insufficient, opposite}` → `faded`
4. `S(N) == not_observed` ve `S(N−1) == not_observed` → `not_observed`
5. `N ≥ 21` ve `nLow < 7` → `few_low`
6. aksi halde → `forming`

`strong` gösterildiğinde `lastShownStrongNight = asOfNight`; ilk kez ise
`firstShownStrongNight = asOfNight`. Zaman damgası yerine gece anahtarı
tutulur: hesap saat okumaz. `paused` (21 gündür kayıt yok) istemcide
belirlenir, bu modülün işi değildir.

EMERGING ve CANDIDATE kullanıcıya gösterilmez (ön kontrol: bağımsız veride
kullanıcıların ~%8–12'si 60 gecede en az bir kez EMERGING'e ulaştı).

### 8. Çıktı
```
{
  engineVersion: "intel-v0.1.0",
  asOfNight, inputHash,
  baseline: { windowDays: 28, energyMean, energyN },
  progress: { pairs, lowNights, otherNights },
  p5: {
    patternType: "low_evening_mood_morning_energy",
    shownState, status, statusPrev,
    pairs, lowNights, otherNights,
    window: { from, to, days: 60 },
    direction: "lower" | "higher" | "none" | null,
    effect, meanLow, meanOther,               // 1 ondalık, hesaplanamazsa null
    evidence: { permutationP, permutations, halfStable },
    firstShownStrongNight, lastShownStrongNight,
  },
}
```
Arayüz yalnız `shownState`, `pairs`, `lowNights`, `window.to` alanlarını
kullanır. `effect`, `p`, `status` ekranda gösterilmez.

## Preregistered simulation (Commit 3)

Üretim modülü (`functions/intel`) aynen kullanılır; ikinci bir istatistik
uygulaması yazılmaz.

**Veri üreticisi (tohumlu):**
- 90 takvim gecesi, başlangıç `2026-01-05`. Her kullanıcıya ait RNG:
  `mulberry32(FNV-1a-32("sim|" + senaryo + "|" + kullanıcıNo))`.
- Her gece tüketim sırası sabittir: ruh hali normali, enerji normali
  (her biri Box–Muller, iki uniform), tamamlanma uniform'u, etki uniform'u.
- Gizli seriler AR(1): `z_0 ~ N(0,1)`, `z_t = ρ z_{t−1} + √(1−ρ²) ε_t`.
  İki seri bağımsızdır. Kategori `1 + #{k : z > probit(cumsum(P)_k)}`,
  `k = 0..3`, probit Acklam yaklaşımı.
- Ruh hali marjinalleri: `tipik [.08,.17,.35,.28,.12]`,
  `nadiren [.02,.05,.33,.40,.20]`, `sik [.15,.25,.30,.20,.10]`.
  Enerji marjinali: `[.08,.20,.37,.25,.10]`.
- Tamamlanma: gece `p = 0.75` ile iki tarafıyla birlikte var; hafta sonu
  senaryosunda akşamı cumartesi ya da pazar olan gecelerde `p = 0.5`.
- Etki (yalnız LOW gecelerde): `β = −1.0` → enerji 1 düşer;
  `β = −0.5` → etki uniform'u `< 0.5` ise enerji 1 düşer. En az 1'e
  sabitlenir. (Onaylanan taslaktaki `round(E + β)` formülü tam sayı E için
  β = −0.5'i yuvarlama yüzünden sıfırlıyordu; aynı beklenen etkiyi taşıyan bu
  tanım sonuç görülmeden seçildi.)
- Dokümanlar: akşam yerel 21:00, sabah ertesi gün yerel 08:00,
  `tzOffsetMin = 180`, uid `sim-<senaryo>-<no>`.
- Değerlendirme: her tamamlanmış geceden sonra üretimdeki gibi
  `computeIntelState` çağrılır, önceki çıktı `previous` olarak taşınır.

**Senaryolar:** Boş: `{tipik, nadiren, sik} × ρ {0, 0.3, 0.6}` ve
`tipik, ρ=0, hafta sonu`. Güç: `tipik, ρ=0, β ∈ {−1.0, −0.5}`.
Zayıflama: `tipik, ρ=0, β=−1.0` ilk 30 gece, sonrasında `β=0`.
Kullanıcı: senaryo başına 2000. `B = 2000`.

**Metrikler:** `everStrong90` = 90 gecede en az bir kez `shownState=strong`
olan kullanıcı oranı; `everStrong60` = aynısı ilk 60 gecede. Zayıflama:
en az bir kez `strong` gösterilen kullanıcılar içinde, sonrasında 90. geceye
kadar `weakened` ya da `faded` görenlerin oranı. Oranlar Wilson %95 aralığıyla
raporlanır. Bilgi amaçlı: `candidate`/`emerging` ulaşma oranları.

**Kabul ölçütleri:**

| Kod | Tür | Ölçüt |
|---|---|---|
| G1 | birincil | ρ ∈ {0, 0.3} tüm boş senaryolar ve hafta sonu: `everStrong90 ≤ 0.05` ve Wilson üst sınırı `≤ 0.065` |
| G2 | birincil (koşullu) | ρ = 0.6 boş senaryolar: `everStrong90 ≤ 0.08` |
| G3 | birincil | 300 kullanıcı, tüm senaryolar, `B = 2000`, iki çalıştırmanın çıktı hash'i aynı |
| S1 | ikincil | Güç β=−1.0: `everStrong60 ≥ 0.60` |
| S2 | rapor | Güç β=−0.5: `everStrong60` |
| S3 | ikincil | Zayıflama oranı `≥ 0.50` |

**Kapı sonucu:** G1 ya da G3 başarısız → `FAIL`. G2 başarısız →
`NEEDS OWNER DECISION` (önceden kayıtlı hafta bloğu permütasyonu önerilir,
onaysız uygulanmaz). S1 ya da S3 başarısız → `NEEDS OWNER DECISION`
(eşik gevşetilmez; ürün uygulanabilirliği tartışılır). Hepsi geçerse `PASS`.

**CI duman testi (kapı değildir):** 200 kullanıcı, `B = 500`,
`tipik ρ=0` boş `everStrong90 ≤ 0.12`, güç β=−1.0 `everStrong60 ≥ 0.35`.

Bu oturumda tasarımdan önce bellekte, farklı bir kodla küçük bir ön kontrol
koşuldu (400 kullanıcı, B=1000); eşikler o tasarım turunda belirlendi ve bu
ADR ile değişmeden donduruldu.

## Alternatives
1. **Beş örüntüyle başlamak.** Çoklu karşılaştırma ve test yükü; kapı
   geçilmeden yatırım büyür. Elendi.
2. **Kişisel (medyan) düşük eşiği.** Anlamı kayar, her kullanıcıda yapay bir
   "düşük" grup yaratır. Elendi.
3. **Welch t / Mann–Whitney / Spearman.** Kütüphane gerektirir, küçük
   örneklemde ya da çok eşit değerde zayıf, ya da cümleyle aynı şeyi ölçmez.
   Elendi.
4. **Claude ile yorum.** Tekrar üretilemez, test edilemez. Elendi.

## Pros / Cons
+ Hesap tamamen bizim, deterministik ve simülasyonla sınanmış
+ Yeni altyapı ve LLM maliyeti yok
− Güç düşük: yalnız büyük etkiler görülür, çoğu kullanıcıda örüntü çıkmaz
− Permütasyon testi geceleri değiştirilebilir varsayar; otokorelasyon riski
  simülasyonla izlenir

## Reason
Ürünün ilk "zekâ" iddiası, rastgele veride yanlış örüntü üretmediği
kanıtlanmadan kullanıcıya gösterilmemeli. En küçük savunulabilir yöntem
ortalama farkı + permütasyon testi + iki ardışık onaydır.

## Consequences
- Eşik, pencere, tohum ya da durum sırası değişirse `engineVersion` artar
  ve simülasyon kapısı yeniden koşulur.
- Commit 4 ve sonrası ayrı onay gerektirir.

## Açık konular
- **Ana sayfa öneri eşlemesi (Commit 7 öncesi):** `recommendForHome` bugün
  günün her saatinde sorulan `calm/good/okay/tired/hard` değerini kullanıyor.
  Kart saate göre enerji ya da 1–5 ruh hali sorduğunda bu değer artık
  üretilmeyecek. Eşlemeyi değiştirmeden sürdürmenin teknik bir yolu olup
  olmadığı Commit 7'den önce owner'a sunulacak.
- Rıza kaydının saklanması, 180 gün, özel nitelikli veri: hukuk görüşü.

## Future Impact
Kapı geçilirse aynı motor P1–P4'e genişletilebilir; her yeni örüntü kendi
simülasyon kapısını geçer. Geri alma maliyeti düşük: modüller bağımsızdır.
