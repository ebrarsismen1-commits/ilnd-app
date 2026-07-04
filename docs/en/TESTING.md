# Testing Guide

## Test Suite Overview

| Layer | Location | Count | Runner |
|-------|----------|-------|--------|
| Unit — validators | `test/core/validators_test.dart` | 18 | `flutter test` |
| Unit — streak copy | `test/core/streak_copy_test.dart` | 7 | `flutter test` |
| Unit — usage meter | `test/core/usage_meter_test.dart` | 7 | `flutter test` |
| Unit — vibe card copy | `test/core/vibe_card_copy_test.dart` | 8 | `flutter test` |
| Widget — login screen | `test/features/auth/login_screen_test.dart` | 3 | `flutter test` |
| Cloud Function — anthropicProxy | `functions/test/anthropicProxy.test.js` | 5 | `npm test` |
| Cloud Function — redeemReferralCode | `functions/test/redeemReferralCode.test.js` | 6 | `npm test` |
| Cloud Function — deleteAccount | `functions/test/deleteAccount.test.js` | 3 | `npm test` |

**Total Flutter tests:** 43  
**Total Cloud Function tests:** 14

---

## Running Flutter Tests

### All tests
```bash
flutter test
```

### With coverage
```bash
flutter test --coverage
# Coverage report at coverage/lcov.info
```

### Specific file or directory
```bash
flutter test test/core/
flutter test test/features/auth/login_screen_test.dart
```

---

## Running Cloud Function Tests

The Firebase Emulator must be running:

```bash
# Terminal 1
firebase emulators:start

# Terminal 2
cd functions
npm test
```

For App Check enforcement tests, set the test app ID:
```bash
export FIREBASE_APP_CHECK_TEST_APP_ID=<your-debug-app-id>
npm test
```

`FIREBASE_APP_CHECK_TEST_APP_ID` is the app ID (not the debug token) registered in Firebase Console → App Check. The test helper calls `admin.appCheck().createToken(appId)` to generate a valid token.

---

## Flutter Test Patterns

### Localization in unit tests

```dart
import 'package:ilnd_app/l10n/app_localizations_tr.dart';

void main() {
  final l10n = AppLocalizationsTr();

  test('validates email', () {
    final validator = Validators.email(l10n);
    expect(validator(''), l10n.validatorEmailRequired);
    expect(validator('notanemail'), l10n.validatorEmailInvalid);
    expect(validator('user@example.com'), isNull);
  });
}
```

### Widget tests with Supabase

`AuthNotifier` reads `Supabase.instance.client` at construction. Initialize it before tests run:

```dart
setUpAll(() async {
  SharedPreferences.setMockInitialValues({});
  await Supabase.initialize(
    url: 'https://example.supabase.co',
    publishableKey: 'test-anon-key',
  );
});
```

### Pumping widgets with animations

`AnimatedBackground` uses an infinite `AnimationController`. Never use `pumpAndSettle()` — it will time out.

```dart
// Wrong — times out
await tester.pumpAndSettle();

// Correct
await tester.pump();
await tester.pump(const Duration(milliseconds: 100));
```

### Provider overrides

```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: const MaterialApp(
      locale: Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LoginScreen(),
    ),
  ),
);
```

### Finding text in RichText / TextSpan

`find.text()` matches plain `Text` widgets only. For `TextSpan` content:

```dart
find.textContaining(l10n.registerLoginLink, findRichText: true)
```

---

## Cloud Function Test Patterns

### Test setup

```javascript
// functions/test/helpers.js
const { getIdTokenForUid, getAppCheckHeaderForTests } = require('./helpers');

// Get a Firebase ID token for test user
const token = await getIdTokenForUid('test-uid-123');

// Get an App Check token (requires FIREBASE_APP_CHECK_TEST_APP_ID)
const appCheckHeader = await getAppCheckHeaderForTests();
```

### Making a test request

```javascript
const httpMocks = require('node-mocks-http');
const { anthropicProxy } = require('../index');

const req = httpMocks.createRequest({
  method: 'POST',
  headers: {
    authorization: `Bearer ${token}`,
    'x-firebase-appcheck': appCheckHeader,
  },
  body: {
    tier: 'quick',
    messages: [{ role: 'user', content: 'Hello' }],
  },
});
const res = httpMocks.createResponse();

await anthropicProxy(req, res);
expect(res.statusCode).toBe(200);
```

### Mocking the Anthropic API

The test suite mocks `global.fetch` for requests to `api.anthropic.com`:

```javascript
jest.spyOn(global, 'fetch').mockImplementation(async (url, opts) => {
  if (url.includes('api.anthropic.com')) {
    return { ok: true, json: async () => mockAnthropicResponse };
  }
  return originalFetch(url, opts);
});
```

This ensures tests don't make real API calls while still exercising all proxy logic.

---

## What Is Not Tested

| Gap | Reason | Risk |
|-----|--------|------|
| `mintFirebaseToken` | Requires real Supabase JWKS endpoint | Low — straightforward JWT validation |
| App Check enforcement in emulator | Requires `FIREBASE_APP_CHECK_TEST_APP_ID` CI secret | Medium — unverified in CI |
| RevenueCat purchase flow | Requires sandbox credentials | Low — RevenueCat SDK handles this |
| Full navigation flow | go_router + Riverpod + Firebase in widget tests | Low — covered by smoke test |
| Dark/light theme rendering | No golden tests | Low — visual regression caught in TestFlight |

---

## CI Integration

Tests run automatically on every push and pull request via GitHub Actions ([`.github/workflows/ci.yml`](../../.github/workflows/ci.yml)):

```yaml
# Flutter jobs
flutter analyze
flutter test --coverage
dart format --set-exit-if-changed lib test

# Cloud Functions job (in firebase emulators:exec)
cd functions && npm ci && npm run lint && npm test
```

Coverage artifacts are uploaded per CI run. The minimum passing bar is all tests green; there is no enforced coverage percentage threshold in v1.0.

---

## Related Documents

- [DEVELOPMENT.md](DEVELOPMENT.md) — how to write new tests
- [ARCHITECTURE.md](ARCHITECTURE.md) — system overview for test context
- [API.md](API.md) — Cloud Function request/response shapes
