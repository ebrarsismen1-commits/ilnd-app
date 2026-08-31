# Analitik Olay Sözlüğü

Uygulamanın Firebase Analytics'e gönderdiği **35 olayın** tam listesi: ne zaman
ateşlenir, ne taşır, hangi soruyu cevaplar.

Sözlüğün varlık sebebi: olaylar 10 dosyaya dağılmış durumda ve yarısı
`AnalyticsService.logEvent(...)` kaçış kapısından, serbest metinle gidiyor.
Bu haliyle panelde bir olay görüldüğünde "bunu kim, ne zaman atıyor" sorusunun
cevabı yalnızca `grep`. Yayından sonra ilk ay sorulacak soru "ne işe yaradı"
olacak; cevabı bu tablo verir.

Tüm çağrılar `lib/core/services/analytics_service.dart` üzerinden geçer.

---

## Nasıl okunur

- **Olay** — Firebase'de göreceğin ad. Tümü `snake_case`.
- **Ne zaman** — tetiklendiği tam an (niyet değil, koddaki satır).
- **Parametre** — olayla giden alanlar. Boşsa parametre yok.
- **Cevapladığı soru** — bu olay panelde neye bakmak için var.

---

## Oturum

| Olay | Ne zaman | Parametre | Cevapladığı soru |
|---|---|---|---|
| `app_open` | Uygulama açılışında, Analytics kurulduktan hemen sonra | — | Günlük/haftalık aktif kullanıcı |

Kaynak: `lib/main.dart:101`. Firebase'in yerleşik `logAppOpen()` olayı.

`AnalyticsService.setUserId()` bir olay değil; sonraki tüm olayları hesaba
bağlar.

---

## Onboarding hunisi

| Olay | Ne zaman | Parametre | Cevapladığı soru |
|---|---|---|---|
| `onboarding_started` | Karşılama ekranı açıldığında | — | Kaç kişi akışa giriyor |
| `onboarding_step_completed` | Hızlı kurulum tamamlanınca | `step_index`, `step_name` | Hangi adım geçiliyor |
| `onboarding_abandoned_at_step` | Uygulama, onboarding yarıdayken arka plana atılınca | `step_index`, `step_name` | Nerede terk ediliyor |
| `onboarding_first_need_picked` | Kullanıcı ilk ihtiyacını seçince | — | İlk niyet beyanı oranı |
| `onboarding_first_entry_skipped` | İlk giriş adımı atlanınca | — | İlk değeri atlayanlar |
| `time_to_first_value` | İlk anlamlı giriş kaydedilince | `seconds` | Değere ulaşma süresi |

Kaynaklar: `welcome_screen.dart:28`, `quick_setup_screen.dart:204`,
`main.dart:224`, `first_entry_screen.dart:124,130,139`.

> **Dikkat:** `onboarding_step_completed` şu an **tek yerden** ve sabit
> `(1, 'quick_setup')` değeriyle çağrılıyor. Yani adım adım huni kurulamaz —
> panelde yalnızca "hızlı kurulumu bitirenler" görünür. Çok adımlı huni
> istiyorsan her adıma birer çağrı eklenmeli.

---

## Referral (viral döngü)

| Olay | Ne zaman | Parametre | Cevapladığı soru |
|---|---|---|---|
| `referral_link_shared` | Davet bağlantısı paylaşım sayfasına gönderilince | `platform` | Kaç davet çıkıyor |
| `referral_signup_completed` | Davet kodu kabul edilip kayıt tamamlanınca | — | Davetin kaçı kayda dönüyor |
| `referral_reward_claimed` | Davet ödülü hesaba işlenince | — | Ödül gerçekten veriliyor mu |

Kaynaklar: `referral_screen.dart:246` (`platform: 'share_sheet'`),
`first_entry_screen.dart:67-68`, `redeem_code_sheet.dart:47-48`.

> `referral_signup_completed` ve `referral_reward_claimed` **her zaman ikili**
> atılıyor (iki ayrı çağrı yerinde de yan yana). Panelde ikisinin sayısı
> birbirinden farklıysa bu bir hata sinyalidir, davranış farkı değil.

---

## Paylaşım kartları

| Olay | Ne zaman | Parametre | Cevapladığı soru |
|---|---|---|---|
| `vibe_card_generated` | Kart ekranı verisiyle ilk kez çizilince (ekran başına bir kez) | — | Kaç kart ekranı doluyor |
| `vibe_card_shared` | Vibe kartı paylaşılınca | `platform` | Üretilenin kaçı paylaşılıyor |
| `quote_card_opened` | Alıntı kartı ekranı açılınca | — | İlgi |
| `quote_card_shared` | Alıntı kartı paylaşılınca | — | Açılanın kaçı paylaşılıyor |
| `streak_card_opened` | Seri kartı ekranı açılınca | — | İlgi |
| `streak_card_shared` | Seri kartı paylaşılınca | — | Açılanın kaçı paylaşılıyor |

Kaynaklar: `vibe_card_screen.dart:46,71`, `quote_card_screen.dart:35,52`,
`streak_card_screen.dart:34,51`.

> Yalnız `vibe_card_*` çiftinin `platform` parametresi var; alıntı ve seri
> kartlarında yok. Kanal kırılımı isteniyorsa üçü aynı şekle getirilmeli.

---

## Yemek analizi

| Olay | Ne zaman | Parametre | Cevapladığı soru |
|---|---|---|---|
| `food_analysis_started` | Fotoğraf okunup analiz ekranına geçilince | — | Kaç analiz deneniyor |
| `food_analysis_completed` | Analiz geçerli bir sonuç döndürünce | — | Kaçı sonuçlanıyor |
| `food_analysis_failed` | Analiz hatayla bitince | `reason` | Hangi sebep baskın |
| `food_entry_saved` | Sonuç "kaydet" ile güne yazılınca | `portion` | Sonucu görenin kaçı kaydediyor |

Kaynak: `lib/features/ekle/yemek_ekle_screen.dart`.

`reason` bir `FoodAnalysisErrorCode` adıdır (`unsupportedImage`,
`photoTooLarge`, `failed`, `failedStatus`, `noInternet`), kullanıcı metni
değil, yani panelde dil bağımsız okunur.

`portion` kullanıcının AI tahminine uyguladığı çarpandır (0.5 / 1 / 1.5 / 2).
Dağılımın 1'den sistematik sapması, görsel tahminin tutarlı biçimde yanlış
olduğu anlamına gelir.

Üçlü birlikte okunur: `started` bir maliyet sayacıdır (her biri bir vision
çağrısı), `completed / started` sağlık oranı, `food_entry_saved / completed`
ise sonucun kullanıcıya değer ifade edip etmediğini söyler.

---

## Gelir hunisi

| Olay | Ne zaman | Parametre | Cevapladığı soru |
|---|---|---|---|
| `free_limit_reached` | Ücretsiz kota bir eylemi engelleyince | `kind` | Hangi duvara kaç kez çarpılıyor |
| `paywall_viewed` | Paywall açılınca | `source` | Hangi ekran ödemeye götürüyor |
| `purchase_started` | Satın alma akışı başlayınca | — | Kaçı denemeye geçiyor |
| `purchase_completed` | Mağaza satın almayı onaylayınca | — | Dönüşüm |
| `purchase_failed` | Satın alma tutmayınca | `reason` | İptal mi, hata mı |
| `restore_completed` | Geri yükleme sonuçlanınca | `restored` | Kaçında aktif abonelik bulundu |
| `restore_failed` | Geri yükleme istisnayla bitince | — | Geri yükleme bozuk mu |

Kaynaklar: `lib/features/premium/paywall_screen.dart`,
`lib/features/ekle/yemek_ekle_screen.dart`.

- `kind` bir `UsageKind` adıdır (`message`, `food`).
- `source` paywall'ı açan ekran (`food`, `chat`, `movement`, `plan`,
  `profile`). Zorunlu parametre: hangi duvarın ödemeye dönüştüğü ancak bu
  ayrımla okunur.
- `purchase_failed.reason`: `cancelled` (mağaza iptal ya da başarısız döndü)
  veya `error` (beklenmedik istisna).
- `restore_completed.restored`: 1 aktif abonelik bulundu, 0 bulunamadı.
  Firebase parametreleri boolean kabul etmediği için sayı olarak gider.

Huni sırayla okunur: `free_limit_reached` → `paywall_viewed` →
`purchase_started` → `purchase_completed`. Her adımdaki düşüş ayrı bir soru.

> `purchase_completed` ve `purchase_failed`, ekran hâlâ açık mı diye
> bakılmadan atılır. Kullanıcı akış biterken çıkmış olabilir ama satın alma
> yine de gerçekleşmiş olabilir; olayın ekrana bağlanması geliri eksik
> saydırırdı.

---

## Seri (streak)

| Olay | Ne zaman | Parametre | Cevapladığı soru |
|---|---|---|---|
| `streak_extended` | Seri bir önceki gözlemin üstüne çıkınca | `days` | Süreklilik |
| `streak_broken` | Seri sıfırlanınca (önceki > 0) | `previous_days` | Nerede kopuyor |
| `streak_milestone_reached` | Bir eşik ilk kez geçilince | `milestone` | Eşikler tutuyor mu |

Kaynak: `lib/core/services/streak_tracker.dart:42,46,55`.

Üçü de `observe()` içinden, aynı gözlem turunda değerlendirilir; bir turda
hem `streak_extended` hem `streak_milestone_reached` atılabilir.

---

## Hareket (video oturumları)

| Olay | Ne zaman | Parametre | Cevapladığı soru |
|---|---|---|---|
| `movement_session_start` | Video hazır olup oynatma başlayınca | `program_id`, `session_id` | Hangi program açılıyor |
| `movement_session_done` | Yeterli süre izlenince (`sessionWatchedEnough`) | `program_id`, `session_id` | Tamamlanma oranı |

Kaynak: `lib/features/movement/movement_player_screen.dart:83,114`.

`start` yalnız oynatma **gerçekten başlarsa** atılır; yükleme hatasında
atılmaz. Yani `done / start` oranı dürüst bir tamamlanma oranıdır.

---

## Hatırlatma

| Olay | Ne zaman | Parametre | Cevapladığı soru |
|---|---|---|---|
| `reminder_enabled` | Bildirim izni alınıp hatırlatma açılınca | — | Kaç kişi hatırlatma istiyor |
| `reminder_disabled` | Hatırlatma kapatılınca | — | Kaçı vazgeçiyor |
| `reminder_time_changed` | Hatırlatma saati değişince | `hour`, `minute` | Tercih edilen saatler |

Kaynak: `lib/core/services/reminder_provider.dart:107,121,137`.

`reminder_enabled` **izin verildikten sonra** atılır — reddedilen izin bu
olayı üretmez.

---

## Kurallar

1. **Tüm çağrılar `AnalyticsService` üzerinden.** `FirebaseAnalytics.instance`
   doğrudan çağrılmaz; sarmalayıcı her metodu `try/catch` ile korur, analitik
   hiçbir zaman uygulamayı çökertmez.
2. **Olay adları `snake_case`**, geçmiş zaman veya durum bildirir
   (`streak_broken`, `movement_session_done`).
3. **Yeni olay eklerken bu tabloya satır eklenir.** Sözlükte olmayan olay,
   panelde anlamı olmayan olaydır. Bu kural testle zorlanır:
   `test/core/analytics_dictionary_test.dart` `lib/` içindeki her olay adının
   bu dosyada geçtiğini doğrular, geçmiyorsa kırılır.
6. **Kalıcı olaylar tipli metot olur**, `logEvent` kaçış kapısı değil: ad
   yazım hatası ancak tipli metotta derleme zamanında yakalanır.
4. **Çağrılar `unawaited(...)` ile yapılır** — analitik kullanıcı akışını
   bekletmez.
5. Firebase sınırları: olay adı ≤ 40 karakter, olay başına ≤ 25 parametre,
   parametre değeri ≤ 100 karakter.

---

## Bilinen boşluklar

Bunlar eksik ölçüm noktaları, hata değil — ama yayın sonrası cevaplanamayacak
sorular:

| Boşluk | Neden önemli |
|---|---|
| **Sohbet: sıfır olay** | Ana AI yüzeyi. Mesaj sayısı, oturum uzunluğu yok |
| **Günün üçlüsü kaldırıldı** | `trio_move_done` / `trio_plate_done` / `trio_recipe_opened` olayları 31 Ağustos'ta özellikle birlikte silindi. Panelde eski veriler durur ama yeni olay gelmez |
| **`logEvent` kaçış kapısı** | 16 olay hâlâ serbest metinle gidiyor. Ad yazım hatası derlemede yakalanmaz; sözlük bekçisi testi (`test/core/analytics_dictionary_test.dart`) en azından belgelenmemiş olayı yakalar |
| **`trio_*_done` yön ayrımı yapmıyor** | İşaret kaldırma da sayılıyor; tamamlama oranı şişik okunur (yukarıdaki not) |

---

## İlgili belgeler

- `lib/core/services/analytics_service.dart` — sarmalayıcı
- `docs/PROJECT_PRINCIPLES.md` — ürün pusulası
- `docs/decisions.md` — karar günlüğü
