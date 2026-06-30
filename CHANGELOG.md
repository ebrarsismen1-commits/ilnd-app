# Changelog

All notable changes to ilnd are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased] — v1.0.0-rc1

This release candidate represents the first production-ready build of ilnd.
It has not yet been distributed via TestFlight or Google Play Internal Testing.
Tag `v1.0.0` will be cut only after external validation passes.

### Security
- **[CRITICAL FIX]** Firestore `user_growth` collection was world-writable;
  any authenticated user could grant themselves unlimited premium status
  directly via Firestore. Moved referral redemption to a server-side Cloud
  Function (`redeemReferralCode`) running under Admin SDK with a Firestore
  transaction; client rules now deny all updates to `founding_member`,
  `premium_access_until`, and `referred_by_code`.
- **[CRITICAL FIX]** Anthropic API key was embedded in the compiled client
  binary via `--dart-define`. Key removed from client entirely; all AI calls
  now route through `anthropicProxy` Cloud Function which holds the key via
  Firebase Secret Manager. Daily per-tier usage caps (quick: 300, deep: 60)
  enforced server-side in a Firestore transaction, not client-side.
- Firebase App Check activated (Play Integrity / App Attest in release;
  debug provider in debug). Enforced on `anthropicProxy`, `redeemReferralCode`,
  `deleteAccount`. `mintFirebaseToken` is intentionally exempt to avoid
  locking users out of login if App Check activation has issues.
- `habits` and `habit_completions` collections had no Firestore rules —
  all habit writes were silently failing (permission-denied) in production.
  Ownership-scoped rules added.
- `deleteAccount` Cloud Function: cascading deletion of Firestore data,
  Storage files, Supabase identity, Firebase Auth user.
- Firebase Crashlytics wired to `FlutterError.onError` and
  `PlatformDispatcher.onError`; previously both were silent `debugPrint` only.

### Added
- **Full internationalization** (TR/EN) — ~270 localized strings; ICU
  pluralization; flutter_localizations + intl; .arb source files.
- **Privacy Policy and Terms of Service** screens, linked from register form
  and profile settings; accessible pre-auth (router bypass added).
- **Account deletion** in-app flow (two-step confirmation → Cloud Function →
  cascading data wipe). Required by Apple App Store Guideline 5.1.1(v).
- **Vibe Card** — weekly wellness summary card (9:16 story format); captured
  as PNG, shared via share_plus.
- **Referral system** — invite code generation, server-side redemption,
  founding-member reward (7-day premium extension, stacks with existing).
- **Habit tracking** — add/delete habits, daily toggle (now atomic via
  Firestore transaction), weekly completion stats on Takip screen.
- **Daily check-in social proof** — anonymous "X people active this week"
  badge on Welcome screen.
- **Onboarding** — consolidated from 4 screens to 3 (welcome → quick-setup
  → first-entry journal); first-entry triggers ILND AI response.
- **CI/CD** — GitHub Actions: analyze + test + format + debug-signed
  build verification on every push/PR; signed .aab release on `v*.*.*` tags.
- Firestore composite indexes (`habit_completions`, `habits`) checked in to
  `firestore.indexes.json`; previously missing, causing runtime index errors.
- Content pipeline: `content/articles.json` canonical source + idempotent
  `seedArticles.js` Admin SDK upsert script; `kArticles` Dart constant is
  now offline-fallback only.
- Test suite: 46 passing tests (validators, usage-metering, streak/vibe-card
  copy, login widget). Cloud Functions emulator tests written (unverified —
  require Firebase Emulator Suite + `FIREBASE_APP_CHECK_TEST_APP_ID`).

### Changed
- Dark mode now covers every screen including auth (login, register, shared
  input field) — previously light-only against a dark animated background.
- `Pressable` widget: disabled state (onTap == null) now dims to 0.45 opacity
  with 150 ms animation; previously showed no visual feedback.
- `toggleCompletion` wrapped in Firestore transaction — eliminates double-tap
  race condition.
- App initialization: each service (Firebase, Supabase, RevenueCat,
  Analytics) wrapped in independent try/catch; Supabase init failure shows
  a retry screen instead of crashing the app.
- Android `build.gradle.kts`: conditional release signingConfig — uses real
  keystore when `android/key.properties` is present, falls back to debug
  key for local development.
- `forceSeed()` removed from `ExploreRepository` and `main()`; replaced by
  `seedIfEmpty()` (client, idempotent guard) for offline bootstrap and
  `seedArticles.js` (Admin SDK) for real content deploys.
- Onboarding: 4 screens → 3; activity-frequency question removed (defaults
  to "Orta aktif").

### Removed
- `name_input_screen.dart`, `onboarding_questions_screen.dart`,
  `value_props_screen.dart` — consolidated.
- `cupertino_icons` dependency — unused Flutter template leftover.
- Plaintext `credentials.txt` and `hesaplar.txt` containing legacy
  ReceiptGPT project keys — deleted from disk.

### Fixed
- Validator error messages now use l10n strings (were hardcoded Turkish).
- `paywall_screen.dart:63` missing `mounted` check after async purchase call.
- `explore_screen.dart:87` underscore-prefixed local variable lint.
- `ilnd_learner.dart:18` missing braces in if-statement (linter fix).
- `signOut()` previously set `AuthUnauthenticated` even on failure; now
  surfaces `AuthError` so the server session is not silently abandoned.

### Known Limitations (see also v1.1 backlog)
- No `ThemeData.dark()` wiring at `MaterialApp` level; dark mode is handled
  by the custom `AppPalette` system. Stock Material widgets (`AlertDialog`,
  `TextButton`, `ElevatedButton`) require per-call-site color overrides.
- Entitlement is still client-seeded from SharedPreferences; RevenueCat sync
  is async. A rooted device can bypass the local flag, but server-side
  `anthropicProxy` caps still apply (bounded revenue risk, not cost-blowup).
- Cloud Functions emulator tests require `FIREBASE_APP_CHECK_TEST_APP_ID` CI
  secret to pass App Check enforcement — currently unverified.
- `skeleton.dart` is dead code (never imported) — flagged for v1.1 cleanup.
- Longest-streak is per-device (SharedPreferences); multi-device users will
  see different values on each device.

---

## Previous
No prior releases — this is the first version of ilnd.
