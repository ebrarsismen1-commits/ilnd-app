# Plan Yazım Kılavuzu

*Rehberli planların (ADR-0005) içeriğini kim yazarsa yazsın tek kaynak bu
belgedir. Teknik karar gerekçeleri `docs/adr/0005-guided-plans-schema.md`'de.*

Bir plan = 7, 14 veya 21 gün. Her gün = **tek okuma + tek adım**. Başka
uzunluk yoktur; 6 günlük bir plan uygulamada hiç görünmez.

---

## 1. Sıra: önce yay, sonra günler, en son JSON

JSON'dan başlama. Üç adım, bu sırayla:

**1. Vaadi tek cümlede yaz.** "Bu planı bitiren kişi ne yaşamış olacak?"
Cümle kurulamıyorsa plan henüz yok demektir.
> *7 gün sakinleşme:* "Bir haftanın sonunda kişi, bedenini dinlenme moduna
> nasıl alacağını biliyor."

**2. Yayı çiz.** Yedi günü tek tek düşünme; üç bölüm düşün:

| Gün | Bölüm | İşi |
|---|---|---|
| 1–2 | **Giriş** | En kolay ve en somut şey. İlk gün asla efor istememeli — "beş dakika, hepsi bu" |
| 3–5 | **Derinleşme** | Asıl fikir burada. Kişi neden işe yaradığını burada anlar |
| 6–7 | **Kapanış** | Toparlama + devam etme yolu. Son gün yeni bilgi vermez, bağlar |

14 ve 21 günlükler aynı yayın uzatılmışı değildir: 14 = iki yay (7+7, ikincisi
uygulama), 21 = üç yay (öğren / uygula / kendi başına sürdür).

**3. Günleri doldur, sonra JSON'a geç.** Tablo hâlinde yeter:
gün no · başlık · hangi makale · hangi adım · not.

---

## 2. Bir günün içeriği

**Başlık** — 2-4 kelime, küçük harf, fiil değil isim. "bacaklar duvara",
"günün tonu". Numara yazma; uygulama "3. gün" kısmını kendi basar.

**Okuma (`articleId`)** — mevcut bir makalenin kimliği. Makale
`content/articles.json`'da yoksa gün okumasız açılır ve `check:plans` hata
verir. Yeni makale gerekiyorsa **önce makaleyi yaz**, sonra plana bağla.

**Adım (`action`)** — beş seçenekten biri, fazlası yok:

| Değer | Uygulamada görünen | Ne zaman |
|---|---|---|
| `breath` | nefes al | Sakinleşme, sinir sistemi, uyku |
| `move` | hareket et | Beden, esneme, yürüyüş |
| `water` | su iç | Beslenme, hidrasyon |
| `journal` | günlüğüne yaz | Farkındalık, şükran, düşünme |
| `none` | *(adım yok)* | Yalnız okuma günü — **ama o gün mutlaka makale taşımalı** |

Aynı adımı arka arkaya üç günden fazla tekrarlama; plan tek nota düşer.

**Not (`note`)** — tek cümle, günün ne isteğini söyler. Kılavuzun tamamı değil,
o günün tek işi. "üç satır yeter. abartma, gerçek olsun."

---

## 3. Üslup kuralları (testle kilitli, tartışmaya açık değil)

Bunlar `test/features/auth/turkish_copy_test.dart` tarafından denetlenir:

- Hitap daima **"sen"** — "yapınız", "deneyiniz" yok
- Akış içi metinler **küçük harf**; yalnız tam cümleler normal düzende
- Kesme işareti daima **düz** (`'`), eğri (`'`) değil
- Emir kipi yumuşak: "dene", "fark et" — "yapmalısın", "unutma" değil
- **Vaat yok:** "stresin %40 azalacak" gibi sayı verilmez. Site öyle yazıyor
  diye uygulama da yazmaz; uygulamada kanıtlayamadığımız iddiada bulunmayız
- **Klinik dil yok:** ürün terapi iddiasında değil (bkz. PROJECT_PRINCIPLES)

**EN çevirisi zorunlu.** Yarım çeviri kabul edilmez: bir planın çevirisi varsa
tüm günleri çevrilmiş olmalı, yoksa `check:plans` hata verir. Çeviri "kelime
karşılığı" değil, aynı üslupta yeniden yazımdır.

---

## 4. Kimlikler — bir kez konur, asla değişmez

`id` alanları kullanıcının ilerlemesinin bağlandığı yerdir. Değiştirilirse
**kullanıcının bitirdiği günler yeniden yapılmamış görünür.**

- Plan id: `7-gun-sakinlesme` — uzunluk + konu, küçük harf, tire, Türkçe
  karakter yok
- Gün id: `d1`, `d2` … sırayla. Gün silinirse kalan günlerin id'si
  **kaymaz** (d3 silinince d4 hâlâ d4'tür)
- Rozet id: `sakinlesme-7`

Yazım hatası fark edersen **başlığı** düzelt, id'ye dokunma.

---

## 5. Rozet

Her planın bir rozeti olmak zorunda; rozetsiz plan yayına çıkamaz.

- PNG, şeffaf zemin, **1024×1024**, kenarlardan %10 boşluk
- Açık **ve** koyu modda okunmalı
- `badges/{planId}.png` yolunda Firebase Storage'da durur
- Adı 2-3 kelime, küçük harf: "sakin hafta"

Rozet bir kez kazanılır ve **asla geri alınmaz** — plan sıfırlansa bile kalır.
Aynı plan ikinci kez bitirilirse rozet çoğalmaz, üzerine tekrar sayacı gelir.

---

## 6. Ücretsiz / premium

- **7 günlük planlar ücretsizdir** (`"premium": false`) — bu ürünün giriş
  basamağı, sitedeki "7 günlük ücretsiz rehber" sözünün karşılığı
- **14 ve 21 günlükler premium** (`"premium": true`)

7 günlük bir planı premium işaretlersen `check:plans` seni uyarır.

---

## 7. JSON şablonu

`content/plans.json` — dosya bir dizidir, her plan bir nesne:

```json
{
  "id": "7-gun-sakinlesme",
  "title": "7 gün sakinleşme",
  "description": "Tek cümlelik vaat. Kişi bunu okuyup başlayacak.",
  "order": 0,
  "premium": false,
  "coverUrl": "https://...",
  "badge": {
    "id": "sakinlesme-7",
    "title": "sakin hafta",
    "imageUrl": "https://firebasestorage.../badges%2F7-gun-sakinlesme.png?alt=media",
    "en": { "title": "a calm week" }
  },
  "days": [
    {
      "id": "d1",
      "title": "bacaklar duvara",
      "articleId": "bacaklar-duvara",
      "action": "breath",
      "note": "beş dakika, hepsi bu."
    }
  ],
  "en": {
    "title": "7 days of calm",
    "description": "...",
    "dayTitles": { "d1": "legs up the wall" },
    "dayNotes":  { "d1": "five minutes, that is all." }
  }
}
```

`order` raf sırasıdır, küçükten büyüğe. Kullanıcının başlaması istenen plan 0.

---

## 8. Yayına verme adımları

```bash
cd functions
npm run check:plans     # format denetimi — Firestore'a dokunmaz
npm run seed:plans      # Firestore'a yazar (kimlik bilgisi gerekir)
```

`check:plans` yeşil olmadan seed edilmez. Denetlediği şeyler:

- uzunluk 7/14/21 mi
- her gün içerik taşıyor mu (makale ya da adım)
- her `articleId` gerçekten `articles.json` içinde var mı
- gün id'leri tekil mi, başlıklar dolu mu
- EN çevirisi eksik gün bırakıyor mu, olmayan güne çeviri var mı
- rozet ve rozet görseli var mı

Uygulama tarafındaki karşılığı `test/features/plans/plans_content_test.dart`
ile kilitlidir: `flutter test` de aynı dosyayı okur. İki taraf da yeşilse
içerik gerçekten görünür demektir.

---

## 9. Lansman için öneri

Altı temayı birden açma. **Üç tema × 7 gün = 21 parça** ile çık; hangisinin
tamamlandığını gör, sonra o temanın 14 ve 21 günlüğünü yaz. Tutmayan temanın
uzun sürümünü hiç yazma.

Sırayı içerik değil **tamamlanma oranı** belirler.
