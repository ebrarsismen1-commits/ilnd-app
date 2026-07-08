# ILND App

## Vision
Gen-Z wellness & lifestyle app → uzun vadede topluluk/etkinlik ekosistemi
(bkz. docs/ilnd_tasarim_vizyonu.md). Ton: warm, minimal, non-preachy.

## Mimari Haritası
- Flutter + Riverpod (StateNotifier) + go_router (redirect'li auth akışı)
- Auth: Supabase → FirebaseAuthBridge → Firestore rules `request.auth`
- `lib/core/` services · repositories · ilnd (AI karakter/servis) · billing · theme · widgets
- `lib/features/<alan>/` ekranlar + provider'lar
- i18n: `lib/l10n/*.arb` — **şablon TR**, EN eşleniği zorunlu; `flutter gen-l10n`
- AI: tüm çağrılar `IlndService` → Cloud Functions `anthropicProxy` (anahtar sunucuda)

## Kapı (her değişiklikten sonra, sırayla)
```
flutter gen-l10n          # .arb değiştiyse
dart format lib test
flutter analyze           # sıfır issue
flutter test              # tümü yeşil
```
CI aynı kapıyı `--set-exit-if-changed` ile koşar; format atlanırsa PR kırılır.

## Sert Kurallar (her biri yaşanmış bir üretim hatasından)
1. **Kullanıcıya görünen metin yalnız .arb'de.** Provider/servis katmanında metin yok —
   hata = enum kod (`AuthErrorCode` deseni), UI `*_l10n.dart` extension'ıyla çevirir.
2. **Kullanıcıya-bağlı her provider** hem `authNotifierProvider`'ı (select uid) hem
   `firebaseAuthUidProvider`'ı izler. İzlemeyen provider = hesaplar arası veri sızıntısı
   veya ilk girişte ölü stream.
3. **`doc.data()!` yasak.** `doc.data() as Map? ?? const {}` + her alanda `?? default`.
4. **Dış HTTP çağrısı timeout'suz olamaz** (LLM için 60 sn, diğerleri 10-30 sn).
5. **StateNotifier'da await sonrası** `if (!mounted) return;`.
6. **Renk yalnız paletten** (`paletteProvider`/`AppColors`), validasyon yalnız
   `Validators`'tan. Hardcoded hex/regex = marka/davranış kayması.
7. Koyu mod iki katmanlı: palet + `AppTheme.dark` (Material overlay'ler). İkisini
   birden düşünmeyen UI değişikliği eksiktir.
8. **AI çağrısında assistant-prefill yasak** (`{'role':'assistant','content':'{'}`)
   — Claude 4.6+ modeller 400 döndürür. JSON istenen yanıt `extractJsonObject`
   (core/ilnd/ai_json.dart) ile ayıklanır.
9. **Görsel/dosya okumada `dart:io File` yasak** — web'de patlar. Image picker'dan
   `XFile.readAsBytes()` + `Image.memory` kullan (desen: avatar_edit.dart).

## Bilinen Tuzaklar
- google_fonts testte: `testWidgets` kullan + `GoogleFonts.config.allowRuntimeFetching=false`
- Firestore stream'i permission hatasından sonra **kendini yenilemez** (kural #2'nin nedeni)
- `kDemoMode` (core/demo) sunum özelliğidir, silme; gerçek akışta `false`
- Windows'ta Chrome/CanvasKit preview güvenilmez → doğrulama widget-test ile

## Görev Yönlendirme
| Görev | Skill |
|---|---|
| Büyük/çok-fazlı iş (3+ katman, "baştan sona") | `plan` (orkestratör) |
| Bug/crash/yanlış davranış | `fix` |
| Yeni özellik/ekran | `build` |
| Davranış değişmeden yapı | `refactor` |
| Görsel/tasarım/tema | `ui` |
| Yavaşlık/jank/boyut | `perf` |
| Yayın hazırlığı | `ship` |
| Yeni feature/bağımlılık/şema ÖNCESİ değerlendirme | `architecture` (build içinden otomatik) |
| Test stratejisi / test yazımı | `testing` |
| ADR / doküman / karar kaydı | `docs` |

## Escalation — DUR ve kullanıcı onayı iste
Büyük refactor · veri kaybı riski · birden fazla savunulabilir mimari · büyük
bağımlılık değişimi · breaking API · database migration · auth/ödeme değişikliği.
(Detay: architecture skill.)

## Kalıcı Belgeler
- docs/PROJECT_PRINCIPLES.md — pusula; çatışmada üstteki ilke kazanır
- docs/adr/ — mimari kararlar (şablon: 0000) · docs/decisions.md — faz karar günlüğü

## Süreç
- Büyük iş = `plan` skill'i (fazlama, öncelik P0-P3, onay kapıları, rapor formatı orada).
- Aynı hata sınıfı ikinci kez görülürse: tüm codebase'de grep'le, hepsini kapat,
  kuralı buraya ekle.
