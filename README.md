# ilnd — iyi hisset, iyi yaşa

A Gen-Z wellness journaling app powered by an AI companion that learns from your entries. Available on iOS and Android.

[![CI](https://github.com/<org>/ilnd_app/actions/workflows/ci.yml/badge.svg)](https://github.com/<org>/ilnd_app/actions/workflows/ci.yml)
[![Flutter](https://img.shields.io/badge/Flutter-3.44.1-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%7C%20Functions%20%7C%20AppCheck-FFCA28?logo=firebase)](https://firebase.google.com)

---

## What it does

- **Daily journaling** — write entries and receive personalized AI responses
- **Habit tracking** — add habits, toggle completions, see weekly stats
- **Nutrition logging** — food photo analysis via AI
- **Vibe Card** — shareable weekly wellness summary (9:16 story format)
- **Referral system** — invite friends, earn premium access
- **ILND AI** — a companion that builds memory from your entries over time

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter 3.44.1 / Dart 3.12.1 |
| State management | Riverpod 2.6.1 |
| Navigation | go_router 14.x |
| Auth | Supabase (email/password) → Firebase Auth (custom token bridge) |
| Database | Firebase Firestore |
| AI | Anthropic Claude (haiku-4-5 / sonnet-4-6) via Cloud Function proxy |
| Subscriptions | RevenueCat / purchases_flutter 8.x |
| Functions | Firebase Cloud Functions v2 (Node 20) |
| Security | Firebase App Check (Play Integrity / App Attest) |
| Observability | Firebase Crashlytics + Analytics |
| i18n | flutter_localizations + intl (.arb files, TR + EN) |
| CI/CD | GitHub Actions |

---

## Quick Start

### Prerequisites

- Flutter 3.44.1 ([install](https://flutter.dev/install))
- Node.js 20.x
- Firebase CLI: `npm install -g firebase-tools`

### Setup

```bash
git clone <repo-url> ilnd_app && cd ilnd_app

# Copy and fill in environment variables
cp .env.example .env

# Install dependencies
flutter pub get
cd functions && npm install && cd ..

# Start Firebase emulators
firebase emulators:start

# Seed article content
cd functions && npm run seed:articles && cd ..

# Run the app
flutter run
```

Full installation guide: [docs/en/INSTALLATION.md](docs/en/INSTALLATION.md)

---

## Security Architecture

Two critical vulnerabilities were fixed in v1.0 that are worth calling out:

1. **Premium self-grant** — `user_growth` was world-writable. Fixed by moving all premium-granting logic to a server-side Cloud Function with Firestore transaction. Client rules now deny all updates to sensitive fields.

2. **API key in binary** — the Anthropic key was compiled into the app via `--dart-define`. Fixed by removing the key from the client entirely. All AI requests proxy through a Cloud Function that holds the key in Firebase Secret Manager.

See [docs/en/SECURITY.md](docs/en/SECURITY.md) for the full threat model.

---

## Project Structure

```
ilnd_app/
├── lib/
│   ├── main.dart                    # App entry, Crashlytics, App Check
│   ├── core/                        # Shared: billing, AI, repos, router, theme, utils
│   └── features/                    # Auth, chat, ekle, explore, habits, home, …
├── functions/                       # Firebase Cloud Functions (Node 20)
│   ├── index.js                     # mintFirebaseToken, anthropicProxy, referral, delete
│   ├── scripts/seedArticles.js      # Content pipeline
│   └── test/                        # Jest test suite (14 tests)
├── content/articles.json            # Canonical article content
├── firestore.rules                  # Firestore security rules
├── firestore.indexes.json           # Composite indexes
├── .github/workflows/               # CI + signed release workflow
└── docs/
    ├── en/                          # English documentation (15 files)
    └── tr/                          # Turkish documentation (15 files)
```

---

## Testing

```bash
# Flutter unit + widget tests (43 tests)
flutter test

# Cloud Functions tests (14 tests, requires emulator running)
firebase emulators:start &
cd functions && npm test

# With coverage
flutter test --coverage
```

---

## Content Pipeline

Articles are managed via JSON and seeded to Firestore:

```bash
cd functions

# Add/update articles (idempotent)
npm run seed:articles

# Also remove deleted articles
npm run seed:articles -- --prune
```

Edit [`content/articles.json`](content/articles.json) to add content. No app update required — Firestore is the live source.

---

## CI/CD

Every push and pull request runs:
- `flutter analyze` — static analysis
- `flutter test --coverage` — unit + widget tests
- `dart format` — format check
- Firebase Emulator + `npm test` — Cloud Functions tests
- Debug APK + AAB build verification

Pushing a `v*.*.*` tag triggers the release workflow: signed AAB artifact ready for Google Play upload.

See [`.github/workflows/ci.yml`](.github/workflows/ci.yml) and [`.github/workflows/release.yml`](.github/workflows/release.yml).

---

## Documentation

| Document | Description |
|----------|-------------|
| [ARCHITECTURE](docs/en/ARCHITECTURE.md) | System design, data model, dual-auth |
| [INSTALLATION](docs/en/INSTALLATION.md) | Local setup |
| [DEVELOPMENT](docs/en/DEVELOPMENT.md) | Daily workflow, theme system, i18n |
| [SECURITY](docs/en/SECURITY.md) | Threat model, Firestore rules, App Check |
| [API](docs/en/API.md) | Cloud Functions reference |
| [FIREBASE](docs/en/FIREBASE.md) | Firestore schema, indexes, emulator |
| [TESTING](docs/en/TESTING.md) | Test patterns, coverage |
| [DEPLOYMENT](docs/en/DEPLOYMENT.md) | Pre-deploy, smoke test, rollback |
| [RELEASE](docs/en/RELEASE.md) | Versioning, release process |
| [APP_STORE_CHECKLIST](docs/en/APP_STORE_CHECKLIST.md) | Store submission |
| [CONTRIBUTING](docs/en/CONTRIBUTING.md) | Commit convention, PR process |
| [TROUBLESHOOTING](docs/en/TROUBLESHOOTING.md) | Common errors |
| [FAQ](docs/en/FAQ.md) | Common questions |
| [CHANGELOG](CHANGELOG.md) | Version history |
| [DEPLOYMENT](DEPLOYMENT.md) | Smoke test + monitoring checklists |

Turkish documentation is available in [`docs/tr/`](docs/tr/).

---

## Known Limitations (v1.0)

- Dark mode requires per-call-site color overrides for stock Material widgets (`ThemeData.dark()` migration planned for v1.1)
- Longest-streak is device-local (SharedPreferences)
- Cloud Functions emulator tests require `FIREBASE_APP_CHECK_TEST_APP_ID` CI secret
- Store listing assets (icon, screenshots, description) not yet created

---

## License

Private — all rights reserved.

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
