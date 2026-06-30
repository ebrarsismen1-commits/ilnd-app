# ilnd

Gen-Z wellness & journaling app — mood check-ins, AI-assisted journaling
(ILND), habit/food tracking, referrals, and a premium tier via RevenueCat.

## Stack

- Flutter + Riverpod + go_router
- Supabase (auth) bridged to Firebase Auth (Firestore security rules need
  `request.auth`) — see `lib/core/services/firebase_auth_bridge.dart`
- Firebase Firestore (data) + Cloud Functions (`functions/`, Node 20)
- Anthropic Claude via a server-side proxy (`functions/index.js`'s
  `anthropicProxy`) — the API key never ships in the client
- RevenueCat (subscriptions)

## Local setup

```bash
cp .env.example .env   # fill in real Supabase/Firebase/RevenueCat values
flutter pub get
flutter gen-l10n
flutter run --dart-define-from-file=.env
```

## Testing

```bash
flutter analyze
flutter test
```

Cloud Functions tests run against the Firebase Emulator Suite (Firestore +
Auth), not against production:

```bash
cd functions
npm install
npm test   # wrapped by `firebase emulators:exec` in CI — see below
```

To run them locally exactly as CI does:

```bash
npm install -g firebase-tools
firebase emulators:exec --project demo-ilnd-test "cd functions && npm test"
```

`mintFirebaseToken` isn't covered by the emulator test suite — it depends on
a real Supabase project's JWKS endpoint, so it's verified manually/in
staging rather than mocked.

`anthropicProxy`/`redeemReferralCode`/`deleteAccount` now run with
`enforceAppCheck: true`. The test suite mints a real App Check token
server-side via `admin.appCheck().createToken()` (see
`functions/test/helpers.js`), which needs a real Firebase App ID set as
`FIREBASE_APP_CHECK_TEST_APP_ID` — **this path is unverified** (never run in
this environment); if those three test files start failing with 401s, set
that env var to your project's app id first.

## Content pipeline (Explore articles)

`content/articles.json` is the single source of truth for article copy —
not the `kArticles` Dart constant, which is only an offline-first/first-run
fallback (see its doc comment in `lib/features/explore/article_model.dart`).
To publish content changes:

```bash
cd functions
npm install
npm run seed:articles            # upserts content/articles.json into Firestore
npm run seed:articles -- --prune # also deletes articles removed from the JSON
```

This requires Application Default Credentials for the target Firebase
project (`gcloud auth application-default login`), since `firestore.rules`
intentionally denies all client writes to `articles` — only an Admin SDK
script or Cloud Function can write there.

## CI/CD

`.github/workflows/ci.yml` runs on every push/PR to `main`:
analyze + test + a debug-signed build-verification build (Android), plus a
separate job that lints and tests `functions/` against the emulator suite.

`.github/workflows/release.yml` fires on `v*.*.*` tags and produces a real,
store-signed `.aab` using repo secrets. See `android/KEYSTORE.md` for how to
generate the upload keystore and wire it into those secrets — this hasn't
been done yet, so pushing a release tag today will fail fast with a clear
error rather than silently produce a debug-signed bundle.

## Repo layout

- `lib/core/` — services, repositories, theme, shared widgets, l10n source
- `lib/features/` — one directory per screen/feature
- `functions/` — Cloud Functions (Supabase↔Firebase auth bridge, AI proxy,
  referral redemption, account deletion) — all of these are server-
  authoritative specifically because the client must never be trusted with
  them (see commit history / `firestore.rules` comments for why)
- `firestore.rules` — security rules; every collection's access pattern is
  commented inline
