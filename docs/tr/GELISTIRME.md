# Geliştirme Kılavuzu

## Günlük İş Akışı

```bash
# 1. Firebase emülatörlerini başlat (bu terminali açık bırak)
firebase emulators:start

# 2. Uygulamayı sıcak yeniden yükleme ile çalıştır
flutter run

# 3. Sıcak yeniden yükleme için 'r', sıcak yeniden başlatma için 'R'
```

---

## Kod Üretimi

ilnd, `.arb` dosyalarıyla `flutter_localizations` kullanır. `lib/l10n/app_tr.arb` veya `lib/l10n/app_en.arb` düzenledikten sonra yerelleştirmeleri yeniden oluştur:

```bash
flutter gen-l10n
```

Oluşturulan dosyalar `.dart_tool/flutter_gen/gen_l10n/` konumunda belirir ve `lib/l10n/app_localizations.dart` aracılığıyla yeniden dışa aktarılır. Oluşturulan dosyaları doğrudan düzenleme.

---

## Yeni Yerelleştirilmiş Dize Ekleme

1. Anahtarı [`lib/l10n/app_tr.arb`](../../lib/l10n/app_tr.arb) (şablon) dosyasına ekle:
```json
{
  "yeniAnahtarim": "Türkçe metin",
  "@yeniAnahtarim": {
    "description": "Profil ekranında X için kullanılır"
  }
}
```

2. Aynı anahtarı [`lib/l10n/app_en.arb`](../../lib/l10n/app_en.arb) dosyasına ekle:
```json
{
  "yeniAnahtarim": "English text"
}
```

3. Yeniden oluştur:
```bash
flutter gen-l10n
```

4. Herhangi bir widget'ta kullan:
```dart
final l10n = AppLocalizations.of(context)!;
Text(l10n.yeniAnahtarim)
```

### ICU Çoğullama

```json
"gunlukSayisi": "{count, plural, =0{Günlük yok} =1{1 günlük} other{{count} günlük}}",
"@gunlukSayisi": {
  "placeholders": { "count": { "type": "int" } }
}
```

---

## Tema Sistemi

Tüm renkler `AppPalette`'ten gelir. Widget'larda hiçbir zaman hex değerlerini sabit kodlama.

```dart
// ConsumerWidget / ConsumerStatefulWidget içinde
final p = ref.watch(paletteProvider);

Container(
  color: p.base,
  child: Text('Merhaba', style: TextStyle(color: p.textPrimary)),
)
```

**Kullanılabilir palet alanları:**

| Alan | Açık Değer | Koyu Değer | Kullanım |
|------|-----------|-----------|---------|
| `base` | `#F7F5FF` | `#0F0E17` | Ekran arka planı |
| `surface` | `#FFFFFF` | `#1C1B27` | Kart/sayfa arka planı |
| `surfaceStrong` | `#EDE9FE` | `#26243A` | Giriş alanı arka planı |
| `accent` | `#8B5CF6` | `#A78BFA` | Birincil eylem, odak halkası |
| `accentSoft` | `#EDE9FE` | `#3730A3` | Çip arka planı |
| `textPrimary` | `#1C1917` | `#F5F3FF` | Gövde metni |
| `textMuted` | `#78716C` | `#A8A29E` | İpucu, yer tutucu |
| `onAccent` | `#FFFFFF` | `#FFFFFF` | Vurgulu arka plan üzerindeki metin |

---

## Durum Yönetimi Kalıpları

### Durum okuma (build metodu)

```dart
class BenimWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aliskanliklar = ref.watch(habitsProvider);
    return aliskanliklar.when(
      data: (liste) => ListView(...),
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Hata: $e'),
    );
  }
}
```

### Eylem çağırma (olay işleyicileri)

```dart
onTap: () => ref.read(habitsNotifierProvider.notifier).addHabit(ad),
```

Callback'lerin içinde hiçbir zaman `ref.watch` çağırma — her zaman `ref.read` kullan.

---

## Test Yazma

### Birim testleri

`test/core/` veya `test/features/` altına yerleştir. Yerelleştirilmiş dizeler için `AppLocalizationsTr()` kullan:

```dart
import 'package:ilnd_app/l10n/app_localizations_tr.dart';

final l10n = AppLocalizationsTr();
expect(Validators.email(l10n)(''), l10n.validatorEmailRequired);
```

### Widget testleri

`pumpAndSettle()` kullanma — `AnimatedBackground` sonsuza dek döner:
```dart
await tester.pump();
await tester.pump(const Duration(milliseconds: 100));
```

### Test paketini çalıştır

```bash
flutter test                    # tüm testler
flutter test test/core/         # sadece birim testler
flutter test --coverage         # kapsam raporu ile
```

### Cloud Functions testleri

```bash
cd functions
npm test                        # Firebase Emülatör çalışıyor olmalı
```

---

## Linting

```bash
flutter analyze                 # Dart analyzer
dart format --set-exit-if-changed lib test   # format kontrolü (CI çalıştırır)
dart format lib test            # formatlamayı uygula
```

---

## Yeni Ekran Ekleme

1. `lib/features/<özellik>/<özellik>_screen.dart` oluştur
2. `ConsumerWidget` (veya yerel durum gerekiyorsa `ConsumerStatefulWidget`) genişlet
3. Tüm renkler için `ref.watch(paletteProvider)` kullan
4. Herhangi bir metin veya validator için `AppLocalizations.of(context)!` ilet
5. Rotayı [`lib/core/router/app_router.dart`](../../lib/core/router/app_router.dart) dosyasına ekle
6. Giriş öncesi erişilebilirse yeniden yönlendirme atlatma listesine ekle
7. Etkileşimli öğelere erişilebilirlik semantiği ekle (minimum 44 piksel dokunma hedefi)

---

## İçerik Hattı

Makaleler JSON aracılığıyla yönetilir:

1. [`content/articles.json`](../../content/articles.json) dosyasını düzenle
2. Seed script'ini çalıştır:
```bash
cd functions
npm run seed:articles
npm run seed:articles -- --prune  # kaldırılan makaleleri de sil
```

Her makalenin kararlı bir `id` alanı olması gerekir.

---

## İlgili Belgeler

- [TEST.md](TEST.md) — test paketi referansı
- [MIMARI.md](MIMARI.md) — sistem tasarımı
- [SORUN_GIDERME.md](SORUN_GIDERME.md) — yaygın hatalar
