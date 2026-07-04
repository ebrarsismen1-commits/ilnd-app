# Development Guide

## Daily Workflow

```bash
# 1. Start Firebase emulators (keep this terminal open)
firebase emulators:start

# 2. Run the app with hot reload
flutter run

# 3. Press 'r' for hot reload, 'R' for hot restart
```

---

## Code Generation

ilnd uses `flutter_localizations` with `.arb` files. After editing `lib/l10n/app_tr.arb` or `lib/l10n/app_en.arb`, regenerate localizations:

```bash
flutter gen-l10n
```

Generated files appear in `.dart_tool/flutter_gen/gen_l10n/` and are re-exported via `lib/l10n/app_localizations.dart`. Do not edit generated files directly.

---

## Adding a Localized String

1. Add the key to [`lib/l10n/app_tr.arb`](../../lib/l10n/app_tr.arb) (the template):
```json
{
  "myNewKey": "Türkçe metin",
  "@myNewKey": {
    "description": "Used on the profile screen for X"
  }
}
```

2. Add the same key to [`lib/l10n/app_en.arb`](../../lib/l10n/app_en.arb):
```json
{
  "myNewKey": "English text"
}
```

3. Regenerate:
```bash
flutter gen-l10n
```

4. Use in any widget:
```dart
final l10n = AppLocalizations.of(context)!;
Text(l10n.myNewKey)
```

### ICU Pluralization

```json
"journalCount": "{count, plural, =0{Günlük yok} =1{1 günlük} other{{count} günlük}}",
"@journalCount": {
  "placeholders": { "count": { "type": "int" } }
}
```

---

## Theme System

All colors come from `AppPalette`. Never hardcode hex values in widgets.

```dart
// In any ConsumerWidget / ConsumerStatefulWidget
final p = ref.watch(paletteProvider);

Container(
  color: p.base,
  child: Text('Hello', style: TextStyle(color: p.textPrimary)),
)
```

**Available palette fields:**

| Field | Light Value | Dark Value | Use For |
|-------|------------|-----------|---------|
| `base` | `#F7F5FF` | `#0F0E17` | Screen background |
| `surface` | `#FFFFFF` | `#1C1B27` | Card/sheet background |
| `surfaceStrong` | `#EDE9FE` | `#26243A` | Input field background |
| `accent` | `#8B5CF6` | `#A78BFA` | Primary CTA, focus rings |
| `accentSoft` | `#EDE9FE` | `#3730A3` | Chip background |
| `textPrimary` | `#1C1917` | `#F5F3FF` | Body text |
| `textMuted` | `#78716C` | `#A8A29E` | Hint, placeholder |
| `onAccent` | `#FFFFFF` | `#FFFFFF` | Text on accent bg |

---

## State Management Patterns

### Reading state (build method)

```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    return habits.when(
      data: (list) => ListView(...),
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
    );
  }
}
```

### Calling actions (event handlers)

```dart
onTap: () => ref.read(habitsNotifierProvider.notifier).addHabit(name),
```

Never call `ref.watch` inside callbacks — always use `ref.read`.

---

## Writing Tests

### Unit tests

Place in `test/core/` or `test/features/`. Use `AppLocalizationsTr()` for localized strings:

```dart
import 'package:ilnd_app/l10n/app_localizations_tr.dart';

final l10n = AppLocalizationsTr();
expect(Validators.email(l10n)(''), l10n.validatorEmailRequired);
```

### Widget tests

```dart
setUpAll(() async {
  SharedPreferences.setMockInitialValues({});
  await Supabase.initialize(
    url: 'https://example.supabase.co',
    publishableKey: 'test-anon-key',
  );
});
```

Do **not** use `pumpAndSettle()` — `AnimatedBackground` loops forever. Use:
```dart
await tester.pump();
await tester.pump(const Duration(milliseconds: 100));
```

### Run the test suite

```bash
flutter test                    # all tests
flutter test test/core/         # unit tests only
flutter test --coverage         # with coverage report
```

### Cloud Functions tests

```bash
cd functions
npm test                        # requires Firebase Emulator running
```

The emulator must be running before Cloud Functions tests execute. Set the `FIREBASE_APP_CHECK_TEST_APP_ID` environment variable for App Check enforcement tests:

```bash
export FIREBASE_APP_CHECK_TEST_APP_ID=<your-test-app-id>
npm test
```

---

## Linting

```bash
flutter analyze                 # Dart analyzer
dart format --set-exit-if-changed lib test   # format check (CI runs this)
dart format lib test            # apply formatting
```

The project follows the `flutter_lints` ruleset. Additional enforced rules:
- `curly_braces_in_flow_control_structures` — always use braces in if/for
- `avoid_print` — use `debugPrint` or structured logging
- `prefer_const_constructors` — use `const` wherever possible

---

## Adding a New Screen

1. Create `lib/features/<feature>/<feature>_screen.dart`
2. Extend `ConsumerWidget` (or `ConsumerStatefulWidget` if local state needed)
3. Add a route in [`lib/core/router/app_router.dart`](../../lib/core/router/app_router.dart)
4. If the screen is accessible pre-auth, add it to the redirect bypass list in the router

```dart
GoRoute(
  path: AppRouter.routeMyFeature,
  builder: (context, state) => const MyFeatureScreen(),
),
```

---

## Content Pipeline

Articles are managed via JSON, not hardcoded Dart:

1. Edit [`content/articles.json`](../../content/articles.json)
2. Run the seed script:
```bash
cd functions
npm run seed:articles           # upsert to Firestore
npm run seed:articles -- --prune  # also delete removed articles
```

Each article needs a stable `id` field — the script uses this for idempotent upserts.

---

## Environment Flags

| Flag | Set Via | Effect |
|------|---------|--------|
| `kDebugMode` | Flutter built-in | Disables Crashlytics in debug |
| `kReleaseMode` | Flutter built-in | Activates real App Check providers |
| `AUTH_BRIDGE_URL` | `.env` / `--dart-define` | Points to mintFirebaseToken URL |

---

## Related Documents

- [TESTING.md](TESTING.md) — full test suite reference
- [ARCHITECTURE.md](ARCHITECTURE.md) — system design
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — common errors
