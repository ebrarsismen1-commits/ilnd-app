# ilnd. — Tasarım Vizyonu

*Bir wellness uygulaması değil, gelecekteki küresel bir wellness ekosisteminin temeli.*

Bu doküman mevcut uygulamanın her ekranını "10 yıl sonra Londra–Berlin–NY–İstanbul'da
eş zamanlı festival düzenleyen, kendi giyim markası olan, milyonlarca günlük kullanıcılı
bir şirket" merceğinden denetler. Korumaya değer olanı söyler, zayıf olanı öldürür,
eksik olanı icat eder.

---

## 0. Önce teşhis: bugünkü ürün hangi arketip?

Referans ürünler iki eksene ayrılır:

- **Performans ekseni** (Strava, WHOOP, Nike Run Club): sayı, rekabet, leaderboard, veri.
- **Varlık ekseni** (Calm, Headspace, Alo): sükunet, ritüel, editoryal, aidiyet.

ilnd bugün **varlık ekseninde** duruyor — günlük, ruh hali, nazik AI arkadaş, "sessiz lüks"
estetiği. Bu doğru bir seçim ve **korunmalı**: performans ekseni kalabalık ve
sermaye-yoğun (donanım, GPS, sensör); varlık ekseninde ise "topluluk + fiziksel etkinlik"
kombinasyonunu gerçekten kuran ürün yok. Calm'ın festivali yok. Headspace'in şehir
buluşması yok. Alo'nun app'i zayıf. **Boşluk tam burada: "kalabalık bir şehirde birlikte
sakinleşmek."** Nike'ın koşuya yaptığını sükunete yapmak.

Bu yüzden bu doküman ilnd'yi bir fitness tracker'a çevirmez. Tam tersi: mevcut duygusal
çekirdeği korur, etrafına **topluluk ve etkinlik katmanı** inşa eder ve her parçayı
on milyonlarca kullanıcıya ölçeklenecek şekilde yeniden çizer.

---

## 1. Marka temeli

### Korunacaklar (bunlar zaten dünya standardında kararlar)
- **"ilnd." sözcük markası** — küçük harf + serif + nokta. Oura, Alo, Aesop ile aynı
  ligde okunuyor. Tişörtün göğsüne, festival sahnesinin arkasına, su matarasının üzerine
  aynen basılabilir. Dokunma.
- **Noto Serif (editoryal) + DM Sans (arayüz) + IBM Plex Mono (sayı)** üçlüsü —
  "dergi gibi uygulama" hissinin kaynağı. Rakiplerin hiçbiri serifi ana ekranda
  kullanmaya cesaret etmiyor; bu ayrıştırıcı. Dokunma.
- **Yeşil #1F9D57 + turuncu #E2611C + ekru zemin** — bu oturumda restore edildi.
  Yeşil = marka, turuncu = enerji anları (etkinlik, kutlama). Merch'te birebir kullanılır.
- **"warm, minimal, non-preachy" ses tonu** — festival sahne anonsundan push
  bildirimine kadar her kanalda aynı ton. Bu cümle şirketin anayasası olmalı.

### Yükseltilecekler
- **Marka jesti eksik.** Nike'ın swoosh'u, Strava'nın turuncu yol çizgisi, Duolingo'nun
  baykuşu var. ilnd'nin tekrarlanabilir görsel jesti yok. Öneri: **"nefes halkası"** —
  yavaşça genişleyip daralan bir çember. Zaten splash'te, mood check-in'de, breath
  ekranında embriyonik olarak var. Bunu bilinçli tek bir motif hâline getir: yükleme
  durumları, streak göstergesi, festival bilekliğindeki LED, hepsi aynı nefes ritmiyle
  (4 sn genişle / 6 sn daral) yaşar. **Animasyon dili = nefes.** Her easing curve bu
  ritimden türetilir.
- **Fotoğraf dili tanımlı ama uygulanmamıştı** — editoryal desature filtresi bu oturumda
  eklendi. Bir adım ileri: kendi çektiğiniz etkinlik fotoğrafları aynı tonda işlenip
  Explore'a girmeli. Stok fotoğraf, ölçekte marka zehridir; her festival kendi görsel
  arşivinizi üretir.

---

## 2. Navigasyon mimarisi — yeniden kuruluş

### Bugün
`Ana Sayfa · Keşfet · [+] · Takip · Profil` + Home'dan girilen tam ekran sohbet.

### Sorunlar
1. **Ürünün ruhu (ILND sohbeti) navigasyonda görünmez.** Kullanıcının "arkadaşı"
   Home'daki bir kartın arkasına saklanmış. Calm'da meditasyon, Strava'da kayıt butonu
   neyse ilnd'de sohbet odur — ama bir tık derinlikte.
2. **"Takip" bir muhasebe defteri gibi konumlanmış.** Makro/su/adım sekmesi
   MyFitnessPal klişesi; "sayıların sekmesi" klinik hissettirir, marka "warm" diyor.
3. **Topluluk diye bir yüzey yok.** On yıllık vizyonun tamamı (etkinlik, festival,
   creator, circle) için ayrılmış tek piksel yok. En büyük eksik bu.
4. **[+] butonu doğru** — tek evrensel "kaydet" jesti. Korunur.

### Yeni mimari — 5 pozisyon

```
Bugün        Keşfet        ( ilnd halkası )        Topluluk        Sen
```

| Pozisyon | Neden var | Neyi çözer | Nasıl ölçeklenir |
|---|---|---|---|
| **Bugün** | Günün ritüeli: selamlama, mood check-in, günün okuması, niyet | "Uygulamayı her gün açmam için tek sebep" sorusu | Wearable verisi, uyku/recovery özeti, AI koç önerisi aynı akışa kart olarak eklenir — sekme sayısı artmaz |
| **Keşfet** | Editoryal dergi + ritüel kütüphanesi | İçerik = markanın sesi; placeholder değil imzalı içerik | Creator programları, koç içerikleri, marka işbirlikleri aynı editoryal gridde "raf" olur |
| **ilnd halkası (merkez)** | Sohbet — ürünün kalbi, navigasyonun tam ortasında, nefes animasyonlu halka | "Arkadaşım her an bir dokunuş uzakta" | AI koçluk derinleştikçe (antrenman planı, beslenme planı) giriş kapısı değişmez; halka markanın kendisi olur |
| **Topluluk** | Etkinlikler + Circle'lar (yeni) | Vizyonun tamamının evi | Şehir bazlı etkinlik listesi → bilet satışı → festival → creator marketplace, hepsi bu sekmenin içinde büyür |
| **Sen** | Profil + takip verisi birleşik | "Takip" defterini kişinin hikâyesine çevirir | Rozetler, yıllık özet (Spotify Wrapped benzeri), merch dolabı, üyelik kartı |

**[+] butonu** merkez olmaktan çıkar, Bugün ekranının sağ üstüne taşınır (Apple
Fitness'ın "..." menüsü gibi) — çünkü merkez artık markanın kalbine (sohbet) aittir.
Alternatif: [+] Bugün ekranında yüzen buton olarak kalır; A/B testlik karar.

**"Takip" sekmesi ölür.** Verisi ölmez — "Sen" sekmesinin üst yarısı olur ve dili
değişir: "bugün 1.840 kcal aldın" (muhasebe) değil, "bugün kendine iyi baktın —
3 öğün, 2L su" (hikâye). Sayı aynı, cümle farklı. WHOOP veriyi böyle anlatır.

---

## 3. Ekran ekran denetim

Her ekran için: neden var / hangi sorunu çözüyor / nasıl ölçeklenir.

### Splash + Onboarding (welcome → quick-setup → first-entry)
- **Neden var:** İlk 60 saniyede "bu uygulama beni tanıyor" hissi.
- **Bugün iyi olan:** first-entry'nin ilk günlük yazısını onboarding'e katlaması —
  Duolingo'nun "önce ders, sonra kayıt" felsefesinin doğru uyarlaması.
- **Zayıf:** Hedef seçimi (kalori/kilo/hareket...) MyFitnessPal dili. "Neye odaklanmak
  istiyorsun" sorusu kalmalı ama seçenekler varlık diliyle yeniden yazılmalı:
  "daha sakin uyanmak", "yemekle barışmak", "bedenimi hareket ettirmek".
- **Ölçek:** Onboarding cevapları AI koçun ilk hafıza tohumudur; ileride şehir seçimi
  eklenir ("İstanbul'dasın — bu ay 2 ilnd buluşması var") ve topluluk katmanı ilk
  dakikada bağlanır.

### Login / Register
- Bu oturumda tamir edildi (per-field hata, sosyal giriş, palet). Tek ekleme:
  **"misafir olarak gez"** yolu. On milyonlarca kullanıcıya giden huninin en büyük
  sızıntısı kayıt duvarıdır; içeriğin bir kısmı (Keşfet) auth'suz gezilebilir olmalı,
  kayıt ancak *kaydetmek istediğin ilk an* istenir (Airbnb modeli).

### Bugün (eski Home)
- **Neden var:** Günlük ritüel çapası. Doğru kurulmuş: selamlama → mood → okuma → niyet.
- **Mood check-in ilnd'nin imza etkileşimidir.** Bu oturumda seçim animasyonu eklendi;
  bir adım ileri: seçimde hafif haptic (iOS `selectionClick`), ardından halka nefes
  animasyonuyla sohbete akış. Bu 3 saniyelik an, markanın Apple Design Award anıdır —
  cilala.
- **Streak dili yumuşatılmalı.** "🔥 7 gün" Duolingo suçluluk mekaniği; ilnd dili
  "7 gündür kendine alan açıyorsun" (kod zaten böyle — koru) + seri kırılınca ceza
  değil şefkat ("ara vermek de bakımın parçası"). Sadakat, korku ile değil gururla kurulur.
- **Ölçek:** Kart mimarisi (Entrance'lı liste) zaten modüler — wearable özeti, etkinlik
  hatırlatması, circle aktivitesi karta dönüşüp eklenir. Ekran tasarımı değişmez.

### Keşfet
- **Öldür:** Emoji'li "stories" şeridi (🌬️😴💧) — Instagram klişesi, dokunulduğunda
  derinliği yok. Yerine: **"Ritüeller"** — 2-5 dakikalık rehberli mikro-pratikler
  (nefes, gece hazırlığı, masa başı esneme). Aynı yatay şerit, ama her kart gerçek
  bir deneyim açar. Calm'ın "Daily Calm"ının mikro hâli.
- **Koru + yükselt:** Hero/featured/feed editoryal gridi. Şart: placeholder 10 makale
  diyetisyen imzalı gerçek içerikle değişir, her makalede yazar imzası görünür
  ("Dyt. [isim]") — imzasız içerik ölçekte güven taşımaz.
- **Ölçek:** Grid'e yeni içerik tipleri raf olarak girer: video ritüel, koç programı,
  etkinlik duyurusu, merch drop. Explore, zamanla "ilnd dergisi + vitrini" olur ama
  hiçbir zaman mağaza gibi görünmez — Kinfolk dergisi gibi görünür.

### ILND Sohbeti
- **Neden var:** Ürünün kalbi; kullanıcıyla ilişkinin kendisi.
- **Zayıf:** Girişin görünmezliği (navigasyon bölümünde çözüldü) ve kişiliğin
  görsel temsili yok — sohbet ekranı düz bir mesajlaşma ekranı.
- **Öneri:** Sohbetin tepesinde nefes halkası yaşar; ILND "düşünürken" halka ritmi
  hızlanır. Ses tonu zaten mükemmel tanımlı (`ilnd_character.dart`) — görsel dil ona
  yetişmeli.
- **Ölçek:** AI koçluğun tüm gelecek yüzeyleri (antrenman önerisi, tabak analizi,
  uyku yorumu) bu tek sohbet kapısından akar. "10 özellik 10 ekran" tuzağına düşme;
  Strava'nın hatası (her özellik ayrı sekme) burada yapılmaz.

### Sen (eski Profil + Takip birleşimi)
- **Neden var:** Kimlik, ilerleme, aidiyet.
- **Koru:** "ILND seni hatırlıyor" hafıza kartı — hiçbir rakipte olmayan duygusal an.
  Rozetler, haftalık özet.
- **Yeniden çerçevele:** Takip verisi buraya "hikâye" dilinde taşınır (bkz. bölüm 2).
- **İcat et:** **Yıllık özet** — "2026'da 214 kez kendine alan açtın, 3 buluşmaya
  geldin, en sakin ayın Eylül'dü." Spotify Wrapped'in kanıtladığı şey: insanlar
  kendileriyle ilgili güzel anlatılmış veriyi *paylaşır*. Vibe card altyapısı zaten var;
  yıllık versiyonu markanın en büyük yıllık organik büyüme anı olur.
- **Ölçek:** Üyelik kartı (aşağıda), merch dolabı, festival bilet geçmişi buraya eklenir.

### Topluluk (YENİ — vizyonun evi)
- **Neden var:** Festival vizyonu bir sekme olarak başlamalı; yoksa hep "app + ayrı
  Instagram hesabı" olarak kalır.
- **v1 içeriği (bugünkü ekiple yapılabilir):**
  - **Buluşmalar:** şehir bazlı etkinlik listesi + RSVP. İlk veri kaynağı: sizin
    düzenlediğiniz İstanbul etkinlikleri. Elle girilen 1 etkinlik bile sekmeyi meşru kılar.
  - **Circle'lar:** 6-12 kişilik, hedef veya şehir bazlı küçük gruplar (örn. "Kadıköy
    sabah yürüyüşçüleri"). Neden feed değil circle? Çünkü 500 kullanıcılı bir global
    feed ölü görünür; 8 kişilik bir circle'da 2 mesaj bile canlı görünür. Küçük ölçekte
    canlılık, tasarımla kurulur.
- **Ölçek:** Circle = temel konteyner. Creator'ın topluluğu bir circle'dır. Koçun
  programı bir circle'dır. Festival bir mega-etkinliktir. Yani marketplace, creator
  economy ve festival aynı iki primitifin (Circle + Etkinlik) üzerine kurulur —
  mimari bugünden buna göre yazılır, ekran sonradan zenginleşir.

### Yemek Ekle / Vibe Card / Referral / Paywall
- **Yemek ekle:** Fotoğraf → AI analiz akışı güçlü. Tek şart: diyetisyen doğrulaması
  (denetim listesinde). Dil "kalori yargıcı" değil "nazik yorum" — kod zaten böyle, koru.
- **Vibe card:** Büyüme motorunun kalbi. Yükselt: etkinlik/festival skin'leri
  ("ilnd İstanbul buluşması · 14 Eylül" damgalı kart) — etkinlik sonrası herkesin
  story'sinde aynı tasarım = bedava billboard.
- **Referral:** Var ve sağlam. Etkinlik kapısına bağlanır: "buluşmaya davet kodunla gel."
- **Paywall → Üyelik.** "ilnd+" bir özellik paketi gibi satılıyor (sınırsız sohbet,
  derin hafıza). Ölçek vizyonunda bu bir **kulüp üyeliğine** dönüşür: özellikler +
  etkinliklere erken kayıt + merch drop'lara erişim + festival ön satışı. Soulcycle/
  Equinox modeli: insanlar özelliğe değil aidiyete abone olur. Ekran dili buna göre
  yeniden yazılır: "ilnd+ üyesi ol" bir fayda listesi değil, bir davetiye gibi durmalı.

### Boş / yükleme / hata durumları
- Shimmer var, editorial gradient fallback var — iyi temel. Standart: her boş durum
  bir davet cümlesi taşır (kod çoğunlukla böyle), her yükleme nefes ritmiyle yaşar
  (shimmer yerine nefes halkası — marka jesti her bekleme anında çalışır).
- Offline: journal/mood yazımı offline kuyruklanmalı (bugün Firestore offline cache
  kısmen veriyor; bilinçli tasarlanmalı). Metroda günlük yazan kullanıcı çekirdek persona.

---

## 4. Tasarım sistemi — token'laştırma

Bugün `AppPalette + AppTextStyles + AppSpacing` var — küçük ekip için doğru. Ölçek için
eksikler:

1. **Motion token'ları:** `breathe` (4s/6s), `settle` (320ms easeOut), `pop` (220ms
   overshoot). Bugün süreler elle serpiştirilmiş; tek dosyada toplanır, her animasyon
   bu üçünden türetilir. Tutarlılık = marka.
2. **Haptic haritası:** `selection` (mood seçimi, tab), `success` (kayıt, streak),
   `arrival` (sohbet cevabı geldi). Tek utility sınıfı; iOS/Android farkını soyutlar.
3. **Elevation kuralı:** Bugün doğru şekilde neredeyse düz (border'lı kartlar).
   Kural yazılı hâle gelir: gölge yalnız 2 yerde — merkez halka ve modal. Başka hiçbir
   yerde. "Luxury without being flashy" bunun disipliniyle korunur.
4. **İkonografi:** Material ikonlar (home, explore, person) jenerik — markasız son
   parça. Orta vadede 20-30 özel çizim outline ikon seti (tek çizgi kalınlığı,
   yuvarlak uçlar, nefes halkasıyla akraba geometri). Bu, "Apple Design Award"
   seviyesine giden en ucuz yatırımlardan biri.
5. **Grid:** 8pt sistem zaten `AppSpacing.unit=8` ile var; ekran şablonları (liste,
   dergi, form) üç layout bileşenine indirgenir — yeni özellik ekleyen kişi layout
   icat etmez, seçer.

---

## 5. Gelecek-geçirmez mimari (kod tarafı ilkeleri)

- **Circle + Etkinlik = iki temel primitif.** Creator, koç, festival, kurumsal wellness
  hepsi bunların özelleşmesi. Firestore şeması bugünden bu iki koleksiyonla başlar.
- **i18n zaten doğru kurulmuş** (arb + l10n) — 100 ülke hedefi için tek eksik: içerik
  (makale/ritüel) çevirisinin CMS katmanı. `content/articles.json` pipeline'ı dil
  boyutu kazanır.
- **Feature flag altyapısı** (Firebase Remote Config) — festival bileti gibi büyük
  özellikler şehir şehir açılır; App Store review beklemeden kapatılabilir.
- **Öde-me/bilet/merch asla kendi ödeme altyapısı ile değil** — bilet: Stripe/iyzico
  link; merch: Shopify. Uygulama vitrindir, kasa dışarıdadır. (App Store %30 komisyon
  kuralına da dikkat: fiziksel mal/etkinlik bileti IAP zorunluluğu dışındadır — doğru
  entegrasyonla komisyonsuz satılır.)
- **Analytics sözlüğü:** her yeni ekranla birlikte event isimleri tanımlanır
  (`event_rsvp`, `circle_join`, `vibe_share`) — Beyza'nın dashboard'u tahminle değil
  sözlükle çalışır.

---

## 6. İş modeli yüzeyleri (mağaza gibi hissettirmeden)

| Gelir | Uygulamadaki doğal yeri | Ne zaman |
|---|---|---|
| ilnd+ üyelik | Üyelik kartı ("Sen") + davetiye dili | Şimdi (RevenueCat kurulumu bekliyor) |
| Etkinlik bileti | Topluluk sekmesi, RSVP akışının ödeme adımı | Faz 2 |
| Merch | Keşfet'te editoryal "drop" kartı + etkinlikte fiziksel satış | Faz 2-3 |
| Koç/creator aboneliği | Circle'ın premium hâli | Faz 3 |
| Festival | Mega-etkinlik: aynı RSVP altyapısı + sponsor rafları | Faz 4 |
| Kurumsal wellness | Circle'ın şirket hâli (kapalı circle + rapor) | Faz 4 |

Hiçbiri yeni bir "mağaza sekmesi" gerektirmez. Hepsi mevcut yüzeylerin özelleşmesidir —
"online mağaza gibi hissettirmeden" şartının cevabı budur.

---

## 7. Sıralama — pazartesi sabahı ne yapılır

Vizyon on yıllık; sıralama acımasız olmalı. Üç kişilik ekip için:

**Şimdi (0-3 ay) — temeli sağlamlaştır + ilk topluluk piksellerini koy**
1. Denetim listesindeki kritikler (kriz kaynağı, KVKK, RevenueCat, sosyal giriş kurulumu)
2. Navigasyon geçişi: Takip → Sen birleşimi, merkez halka (sohbet), Topluluk sekmesi
   v1 (elle girilen etkinlik listesi + RSVP)
3. İlk İstanbul buluşması + etkinlik-skinli vibe card
4. Placeholder içerik → diyetisyen imzalı içerik

**Sonra (3-9 ay)**
5. Ritüeller (stories yerine), push bildirimi (streak-koruma), haptic + motion token'ları
6. Circle v1 (tek şehir, elle onaylanan gruplar)
7. İlk merch denemesi (etkinlikte satılan tek ürün — tişört/matara)

**Daha sonra (9-24 ay)**
8. Özel ikon seti, yıllık özet (Wrapped), ikinci şehir, koç/creator pilotu

Her faz bir öncekinin kanıtını ister: buluşma doluyor mu → circle canlı mı → merch
satıyor mu → o zaman festival. Nike Run Club da böyle kuruldu; ilk gün swoosh yoktu,
ilk gün koşu vardı.

---

## 8. Pano kalibrasyonu (2026-07-03 — Pinterest vision board'dan)

Kurucunun panosu incelendi; görsel yön şu şekilde kalibre edildi:

- **Koyu mod nötr kömür değil, botanik siyah:** zemin `#131A12` (yeşile çalan), yüzey
  `#1C2619`, vurgu `#7FCE9E`, matcha vurgu `#A9C77A`. Panodaki koyu kartlar
  (şişe yeşili üzerine beyaz serif) bu dilin kaynağı.
- **Açık mod:** krem `#F6F4EC` + editoryal krem kart `#EFEBDD`, derin yeşil blok
  `#274D33`, matcha `#9BAA6F`, matcha-soft `#E8EDDA`. Metin `#1C2418` (yeşile çalan mürekkep).
- **Fotoğraf dili:** soluk/desature DEĞİL — doğal-sulu botanik yeşiller (matcha,
  brokoli makrosu, zeytinyağı). CoverImage'daki `sat=-35` filtresi yumuşatılmalı (~-15).
- **Tipografi imzası:** serif başlıkta *italik kelime vurgusu* ("yeşile geçişin *bilimi*").
  Panodaki "science of *self-care*" dilinin uyarlaması — tüm hero başlıklarında kullanılır.
- **Blok renk kartları:** ritüel/CTA kartları düz derin yeşil, krem veya matcha
  zemin + serif beyaz metin (panodaki DTC marka kartları gibi).

Figma dosyası: https://www.figma.com/design/dMUmZ7PzUFYem6LJeS9lPG — v2 gündüz+gece
ekran script'i hazır, Starter planın MCP limiti açıldığında tek çağrıyla kurulacak.

---

*ilnd. — feel good, live good. Önce bir kişiye, sonra bir şehre, sonra dünyaya.*
