# Troubleshooting Guide

## Flutter / Dart

### `flutter pub get` fails

```bash
flutter clean
rm -rf .dart_tool/ .flutter-plugins .flutter-plugins-dependencies
flutter pub get
```

### `flutter analyze` reports errors after a merge

Regenerate localizations first — generated files can be out of sync:
```bash
flutter gen-l10n
flutter analyze
```

### App shows `_StartupFailureApp` on launch

Supabase initialization failed. Check:
1. `SUPABASE_URL` in `.env` — must match your Supabase project URL exactly
2. `SUPABASE_ANON_KEY` — must be the public anon key (not the service role key)
3. Network connectivity in the emulator/device

### Hot reload works but changes don't appear

Some changes require a hot **restart** (press `R` in the terminal, or use IDE restart):
- Provider definitions changed
- Router configuration changed
- `.arb` file changes (also requires `flutter gen-l10n`)

### `pumpAndSettle()` times out in widget tests

`AnimatedBackground` runs an infinite animation. Replace with:
```dart
await tester.pump();
await tester.pump(const Duration(milliseconds: 100));
```

### Widget test shows wrong locale

Explicitly set the locale in the test's `MaterialApp`:
```dart
child: const MaterialApp(
  locale: Locale('tr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MyScreen(),
),
```

---

## Firebase / Firestore

### Firebase emulator fails to start

Check that required ports are free:
```bash
# macOS / Linux
lsof -i :4000 -i :5001 -i :8080 -i :9099 -i :9199

# Kill conflicting process
kill -9 <PID>
```

Re-run:
```bash
firebase emulators:start
```

### Emulator starts but app still calls production Firebase

The Flutter app connects to emulators only when `kDebugMode == true` and the emulator host is configured in `main.dart`. If you're running a profile or release build, it will hit production.

Always test with `flutter run` (debug mode).

### Firestore writes silently fail

Most likely a security rules rejection. Check the Emulator UI at [http://localhost:4000](http://localhost:4000) → Firestore → Requests tab for permission-denied errors.

Common cause: writing to a field that the rules protect (e.g., `founding_member` in `user_growth`).

### `habit_completions` query fails with "index required"

The composite index `userId ASC + date ASC` must be deployed:
```bash
firebase deploy --only firestore:indexes
```

Or follow the link in the error message to create the index in the Firebase Console.

### Cloud Function returns 401

- Missing or expired Firebase ID token in the `Authorization` header
- Missing App Check token in `X-Firebase-AppCheck` header (for enforced functions)
- In tests: check that the emulator is running and `FIREBASE_APP_CHECK_TEST_APP_ID` is set

### Cloud Function returns 429

The user has hit their daily AI usage cap:
- `quick` tier: 300 requests/day
- `deep` tier: 60 requests/day

The count resets at midnight UTC. In development, delete the `ai_usage/{uid}/` documents in the Emulator UI to reset the counter.

### `mintFirebaseToken` returns 401

The Supabase JWT is invalid or expired. Check:
1. The token is from the current user's session (`Supabase.instance.client.auth.currentSession?.accessToken`)
2. `SUPABASE_URL` in the Cloud Function environment matches the project that issued the JWT

### Articles not loading from Firestore

Run the seed script:
```bash
cd functions
npm run seed:articles
```

If using the emulator, the emulator must be running before seeding. The `articles` collection is empty by default — the seed populates it.

---

## Authentication

### Login works but Firestore reads fail

The Firebase bridge may not have completed. After Supabase login, `mintFirebaseToken` is called to bridge to Firebase Auth. If this fails silently, Firestore rules see no `request.auth`.

Check `AuthNotifier._bridgeToFirebase()` in [`lib/features/auth/auth_provider.dart`](../../lib/features/auth/auth_provider.dart) for error handling.

### `AUTH_BRIDGE_URL` not set — AI chat shows error

After deploying Cloud Functions, update `AUTH_BRIDGE_URL` in `.env`:
```ini
AUTH_BRIDGE_URL=https://<region>-ilnd-app-8dcbd.cloudfunctions.net/mintFirebaseToken
```

The sibling function URLs (`anthropicProxy`, `redeemReferralCode`, `deleteAccount`) are derived automatically from this base URL.

### Account deletion fails partway through

`deleteAccount` performs best-effort deletion. If Supabase deletion fails (network issue, service outage), the Firebase Auth user is still deleted and the Firestore data is wiped. The Supabase user may remain as a dangling record — clean it up in the Supabase dashboard if needed.

---

## RevenueCat / Premium

### Purchase flow completes but `isPremiumProvider` stays false

RevenueCat entitlement sync is asynchronous. `isPremiumProvider` reads SharedPreferences first, then syncs from RevenueCat. Force a sync:
```dart
await ref.read(revenueCatServiceProvider).syncPremiumStatus();
```

Or restart the app — the sync happens on every app launch.

### Paywall shows but purchases are disabled

In iOS Simulator, StoreKit testing must be enabled. Use a physical device for full purchase testing, or configure `StoreKit Configuration File` in Xcode scheme settings.

---

## CI/CD

### CI fails on `dart format`

Run locally and commit the formatted output:
```bash
dart format lib test
git add -u
git commit --amend --no-edit
```

### Release workflow fails — "keystore secrets not configured"

The GitHub Actions secrets are not set:
- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_STORE_PASSWORD`

See [`android/KEYSTORE.md`](../../android/KEYSTORE.md) for how to generate the keystore and encode it.

### Cloud Function tests fail in CI

1. `FIREBASE_APP_CHECK_TEST_APP_ID` secret is not set in GitHub Actions
2. Firebase Emulator failed to start — check CI logs for emulator startup errors

---

## Related Documents

- [INSTALLATION.md](INSTALLATION.md) — initial setup
- [DEVELOPMENT.md](DEVELOPMENT.md) — daily workflow
- [FIREBASE.md](FIREBASE.md) — Firestore and emulator configuration
- [FAQ.md](FAQ.md) — common questions
