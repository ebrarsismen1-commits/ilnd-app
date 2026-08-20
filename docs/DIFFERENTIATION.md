# ilnd — Özgün Yön ve Ayrışma Noktaları

*Hedef kitle: bitirme projesi ön görüşme jürisi. Tek kaynak belge — sunum,
rapor ve savunma metinleri buradan türetilir.*

Belgedeki her iddia bir kod/ADR/test referansına bağlıdır. Referansı olmayan
iddia bu belgeye girmez.

---

## 1. Tek cümle

> ilnd, kullanıcıyı zamanla tanıyan bir AI arkadaşın etrafında kurulmuş,
> dijital ritüelden gerçek şehir buluşmasına uzanacak biçimde tasarlanmış,
> Türkçe-öncelikli bir wellness uygulamasıdır.

Anahtar kelime **"Türkçe-öncelikli"**: uygulamanın şablon dili TR, İngilizce
eşleniği zorunlu (461 dize, iki dilde tam eşleşme). Global rakiplerin tersi.

---

## 2. Problem tanımı

Wellness uygulamaları iki eksene ayrılıyor:

- **Performans ekseni** (Strava, WHOOP, Nike Run Club): sayı, rekor, leaderboard.
  Kalabalık ve sermaye-yoğun (donanım, GPS, sensör).
- **Varlık ekseni** (Calm, Headspace): sükunet, ritüel, editoryal içerik.
  Ama içerik tek yönlü — uygulama kullanıcıyı tanımaz ve fiziksel dünyaya çıkmaz.

Üç somut boşluk:

1. **Kişiselleşme sahte.** "Kişiselleştirilmiş" denen içerik çoğunlukla
   onboarding'de seçilen etikete göre filtrelenmiş sabit kütüphane. Uygulama
   kullanıcı hakkında hiçbir şey *biriktirmiyor*.
2. **Türkçe deneyim çeviri kalitesinde.** Global ürünlerin TR sürümü İngilizce
   kurulmuş cümlelerin Türkçe kelimelerle dizilmesi. Duygusal bir üründe bu
   doğrudan güven kaybı.
3. **Topluluk yok.** Wellness pratiği doğası gereği sosyal (yoga stüdyosu, koşu
   kulübü) ama uygulamalar bireysel ve dijital kalıyor.

---

## 3. Mevcut çözümlerle karşılaştırma

| | Calm / Headspace | Strava / Nike RC | Yerel TR wellness app'leri | **ilnd** |
|---|---|---|---|---|
| Ana eksen | Varlık | Performans | Karışık | Varlık |
| Kişiselleşme | Etiket bazlı filtre | Sensör verisi | Zayıf | **Konuşmadan çıkarılan kalıcı hafıza** |
| Türkçe | Çeviri | Çeviri | Yerli ama AI yok | **Yerli + AI dil kuralı kilitli** |
| AI güvenliği | — / prompt bazlı | Yok | Yok | **Deterministik kriz ağı (model-bağımsız)** |
| Fiziksel topluluk | Yok | Segment/kulüp (dijital) | Yok | **Etkinlik/RSVP şeması kurulu (ADR-0002)** |
| Görsel dil | Yumuşak/jenerik | Sportif | Jenerik | **Editoryal — ana ekranda serif tipografi** |

Boşluk tam olarak sağ sütun: *kalabalık bir şehirde birlikte sakinleşmek.*

---

## 4. Özgün yön — iddia / kanıt / neden kolay kopyalanamaz

### 4.1 Konuşmadan biriken kalıcı hafıza
**İddia.** Uygulama her günlük ve mesajdan hedef/gerçek çıkarıp kalıcı hafızaya
işler; bu hafıza sonraki her AI çağrısına bağlam olarak verilir. Kullanıcı
deneyimi: "geçen hafta yazdığımı hatırlıyor."

**Kanıt.** `lib/core/ilnd/ilnd_learner.dart` (ucuz modelle çıkarım,
fire-and-forget), `lib/core/ilnd/ilnd_memory.dart` (hedefler, gerçekler, son
notlar), `ilnd_service.dart` içinde bağlam enjeksiyonu.

**Neden zor.** Değer zamanla artar — 3 aylık kullanıcının hafızası taklit
edilemez. Klasik "her istek bağımsız" chatbot mimarisinden farklı bir veri
modeli gerektirir.

### 4.2 Deterministik kriz güvenlik ağı
**İddia.** Kullanıcının kendi sözleri kendine zarar sinyali içeriyorsa, model ne
cevap verirse versin somut insan kaynakları gösterilir.

**Kanıt.** `lib/core/ilnd/crisis_guard.dart` — ağ çağrısı yok, eşleşen metin
loglanmıyor, kasıtlı olarak basit (sessizce başarısız olamaz). AI cevabını
*engellemez*, üstüne ekler.

**Neden önemli.** Ruh sağlığına değen AI ürünlerinde asıl risk burada ve çoğu
çözüm bunu yalnızca prompt'a bırakıyor — yani olasılıksal bir sisteme güvenlik
kritik bir görev veriyor. Bu, projenin en savunulabilir mühendislik kararı.

### 4.3 AI'ın Türkçesi: "dili" değil "nasıl yazacağını" söyleyen kural
**İddia.** Prompt'a "Türkçe konuş" demek yetmiyor; model İngilizce kurduğu
cümleyi Türkçe kelimelerle diziyor ("welcome back" → "hoş geldin geri").
Karakter prompt'undaki dil kuralı bu yüzden üslup düzeyinde yazıldı.

**Kanıt.** `lib/core/ilnd/ilnd_character.dart` içinde `_turkishRule`;
kural kısaltılırsa test kırılır. CLAUDE.md Sert Kural #17 bu hatanın
üretimde yaşandığını kayda alıyor.

**Neden zor.** Bulunması için ürünü Türkçe yaşamak gerekiyor. Tek prompt tüm AI
yüzeylerini beslediği için (sohbet, günlük yorumu, yemek analizi) bu tek satırlık
zayıflık her yerde aynı anda görünüyordu — düzeltmesi de tek noktadan.

### 4.4 Metin konvansiyonlarının testle kilitlenmesi
**İddia.** Kullanıcıya görünen tüm metin `.arb` dosyalarında (461 dize, TR/EN
tam eşleşme); üslup kuralları (hitap "sen", bölüm etiketleri ALL CAPS, akış içi
butonlar küçük harf, düz kesme işareti) otomatik testle doğrulanıyor.

**Kanıt.** `lib/l10n/app_tr.arb` ↔ `app_en.arb`,
`test/features/auth/turkish_copy_test.dart`, CLAUDE.md Sert Kural #1 ve #16.

**Neden ilginç.** Marka tutarlılığını *derleme zamanı garantisi* haline getirmek
alışılmadık bir yaklaşım — genellikle stil rehberi bir PDF'te durur ve sapar.

### 4.5 Kota/limit sunucuda, cihazda değil
**İddia.** AI kullanım hakkı kullanıcı hesabına (uid) bağlı, sunucuda tutulur ve
sunucuda uygulanır; istemci yalnız okur.

**Kanıt.** `ai_usage/{uid}_{hafta}` dokümanı + `firestore.rules` içinde
`allow write: if false`, sunucu tarafı `anthropicProxy` Cloud Function.
CLAUDE.md Sert Kural #13 (önceki cihaz-yerel çözümün neden çöktüğü yazılı).

**Neden önemli.** AI ürünlerinde maliyet kontrolü varoluşsal. "Kullanıcının
yazabildiği yerde sınır yoktur" ilkesi hem güvenlik hem birim ekonomisi kararı.
API anahtarı hiçbir zaman istemcide bulunmuyor.

### 4.6 Uygulama değil, ekosistem temeli
**İddia.** Etkinlik/RSVP veri şeması ve video tabanlı hareket programı altyapısı
kurulu; ürün tek kişilik dijital deneyimden şehir buluşmasına geçecek biçimde
tasarlandı.

**Kanıt.** `docs/adr/0002-events-rsvp-schema.md`,
`docs/adr/0004-movement-programs-video.md`, `lib/features/topluluk/`.

**Dürüst kapsam notu.** Bu katmanın kodu hazır, henüz canlıda değil (bkz. §7).

---

## 5. Teknik yaklaşım ve dikkate değer kararlar

- **Flutter + Riverpod + go_router**, tek kod tabanı → Android/iOS/web.
- **Çift kimlik mimarisi:** kimlik Supabase'de, veri Firestore'da;
  `FirebaseAuthBridge` custom token üretiyor. Karmaşıklık bilinçli ve ADR'da
  gerekçeli (`docs/adr/0001-supabase-firebase-dual-auth.md`), migration riski
  taşıma maliyetinden büyük olduğu için. **Bedeli de yazılı:** kullanıcıya bağlı
  her provider iki auth kaynağını birden izlemek zorunda (Sert Kural #2) — aksi
  halde hesaplar arası veri sızıntısı.
- **AI çağrıları istemciden yapılmaz:** tümü `IlndService` → Cloud Functions
  `anthropicProxy`. Anahtar sunucuda, timeout zorunlu (LLM 60 sn).
- **E-posta/deep link tutarlılığı** üç yerde birden tanımlı olmak zorunda (Dart
  sabiti, native config, sağlayıcı allowlist'i); biri eksikse akış *sessizce*
  ölüyor. Tutarlılık testle kilitli (`test/features/auth/deep_link_config_test.dart`).

Jüriye asıl anlatılacak şey bu maddelerin *içeriği* değil, **hepsinin bir
üretim hatasından doğmuş olması ve tekrarını engelleyen bir teste bağlanması.**

---

## 6. Mühendislik disiplini (ölçülebilir)

| Ölçüt | Değer |
|---|---|
| Uygulama kodu | 110 Dart dosyası, ~28.500 satır |
| Test | 43 test dosyası, ~4.000 satır |
| Yerelleştirme | 461 dize × 2 dil, tam eşleşme zorunlu |
| Mimari karar kaydı | 4 ADR (şablon + karar günlüğü) |
| Kalite kapısı | `gen-l10n` → `dart format` → `flutter analyze` (sıfır issue) → `flutter test`; CI aynı kapıyı `--set-exit-if-changed` ile koşar |
| Kurumsal hafıza | CLAUDE.md'de 17 "sert kural" — her biri yaşanmış bir üretim hatasından türetilmiş |

Bu tablo, ön görüşmede "bitmiş bir demo mu, sürdürülebilir bir sistem mi?"
sorusunun cevabıdır.

---

## 7. Kapsam dürüstlüğü — neyin bittiği, neyin bitmediği

**Çalışıyor:** auth akışları (e-posta + deep link), onboarding, günlük, ruh hali,
AI sohbet + hafıza + kriz ağı, Bugünün Üçlüsü, Keşfet, paylaşılabilir kartlar,
kullanım kotası, koyu mod, iki dil.

**Kodu hazır, canlıda değil:** topluluk sekmesi/etkinlik RSVP (kural deploy'u ve
seed bekliyor), video tabanlı hareket programları (henüz içerik/video yok —
ürün ilkesi: içerik yokken raf gösterilmez).

**Dış bağımlılığa takılı:** sosyal giriş sağlayıcı kimlikleri, ödeme ürün
tanımları, mağaza yayın süreci, hukuki metin onayı.

Jüri karşısında bu ayrımı **önce sen** söyle. "Her şey bitti" iddiası ilk
soruda yıkılır; kapsamı kendin çizersen tartışmayı sen yönetirsin.

---

## 8. Beklenen jüri soruları ve cevapları

**"Bu bir ChatGPT wrapper değil mi? Özgünlük nerede?"**
Model dışarıdan; özgünlük modelin *etrafındaki sistemde*: konuşmadan hafıza
çıkarma ve geri besleme döngüsü (§4.1), modelden bağımsız çalışan kriz güvenlik
ağı (§4.2), tek noktadan tüm AI yüzeylerini besleyen ve testle kilitlenmiş dil
kuralı (§4.3), sunucuda uygulanan kota mimarisi (§4.5). Modeli değiştirsem bu
katmanların hiçbiri değişmez — asıl ürün bu.

**"Calm/Headspace zaten var, senin farkın ne?"**
İki eksenli konumlandırma (§3). Onlar kullanıcıyı tanımıyor ve fiziksel dünyaya
çıkmıyor; ikisi de mimari olarak planlanmış farklar, sonradan eklenen özellik
değil.

**"Modeli sen mi eğittin?"**
Hayır, model eğitimi yok — bu projenin iddiası da o değil. İddia: hazır bir dil
modelini duygusal bir üründe *güvenli, tutarlı ve maliyeti kontrollü* biçimde
çalıştıran uygulama mimarisi. Kriz ağı ve sunucu-taraflı kota bunun somut
kanıtları.

**"Ruh sağlığı hassas bir alan, sorumluluğu nasıl ele alıyorsun?"**
§4.2. Ayrıca ürün terapi iddiasında değil; ton "warm, minimal, non-preachy"
olarak tanımlı ve klinik dilden bilinçli kaçınıyor.

**"Neden iki farklı backend? Gereksiz karmaşıklık değil mi?"**
Karmaşıklık gerçek ve ADR-0001'de yazılı. Kimlik ve veri farklı zamanlarda
farklı sistemlerde doğdu; yayın öncesi migration riski köprüyü taşıma
maliyetinden büyük. Karar geri dönülebilir ve tetikleyicisi tanımlı (aylık aktif
> 50k veya köprü kaynaklı ikinci olay).

**"Test kapsamın yeterli mi?"**
Kapsam oranı hedeflemiyorum; *hata sınıfı* hedefliyorum. Aynı sınıf hata ikinci
kez görülürse tüm kod tabanında aranıp hepsi kapatılıyor ve kural CLAUDE.md'ye
ekleniyor. 43 test dosyasının çoğu bu yolla doğdu.

**"Kullanıcı verisi nerede, KVKK?"**
Kimlik Supabase, uygulama verisi Firestore; Firestore kuralları `request.auth`
zorunlu kılıyor, kota dokümanına istemci yazamıyor. Hukuki metinler avukat
onayında (§7).

---

## 9. 10 dakikalık ön görüşme akışı

| Süre | İçerik |
|---|---|
| 1 dk | Problem: üç boşluk (§2) — tek slayt, kişisel bir örnekle |
| 1 dk | Konumlandırma matrisi (§3) — boş çeyreği göster |
| 3 dk | **Canlı demo, tek akış:** günlük yaz → ertesi gün ILND o hedefi hatırlayarak karşılasın. Hafızayı anlatma, gösterip sus. |
| 2 dk | Özgün yön: §4.1, §4.2, §4.3 — üçü yeter, altısını sayma |
| 1 dk | Mimari şeması + mühendislik tablosu (§5, §6) |
| 1 dk | Kapsam: biten / bitmeyen / dış bağımlılık (§7) |
| 1 dk | Sonraki faz ve tetikleyicileri (`docs/PRODUCT_ROADMAP.md`) |

Kural: demoda **tek bir "aha" anı** yeter. Özellik turu jüriyi ikna etmez,
hatırlanan tek bir an eder.

---

## İlgili belgeler
- `docs/ilnd_tasarim_vizyonu.md` — konumlandırma ve on yıllık vizyon
- `docs/PROJECT_PRINCIPLES.md` — çatışmada karar veren ilke sırası
- `docs/ARCHITECTURE_BLUEPRINT.md` · `docs/mimari_semalar.html` — mimari görselleri
- `docs/adr/` — mimari kararlar ve gerekçeleri
- `docs/PRODUCT_ROADMAP.md` — Now / Next / Later
