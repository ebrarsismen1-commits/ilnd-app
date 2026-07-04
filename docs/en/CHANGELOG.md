# Changelog

See also the root [`CHANGELOG.md`](../../CHANGELOG.md) for the canonical version. This document is a copy maintained in the `docs/en/` tree for documentation completeness.

All notable changes to ilnd are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased] — v1.0.0-rc1

This release candidate represents the first production-ready build of ilnd.
It has not yet been distributed via TestFlight or Google Play Internal Testing.
Tag `v1.0.0` will be cut only after external validation passes.

### Security

- **[CRITICAL FIX]** Firestore `user_growth` collection was world-writable; any authenticated user could grant themselves unlimited premium status directly via Firestore. Moved referral redemption to a server-side Cloud Function (`redeemReferralCode`) running under Admin SDK with a Firestore transaction; client rules now deny all updates to `founding_member`, `premium_access_until`, and `referred_by_code`.
- **[CRITICAL FIX]** Anthropic API key was embedded in the compiled client binary via `--dart-define`. Key removed from client entirely; all AI calls now route through `anthropicProxy` Cloud Function which holds the key via Firebase Secret Manager. Daily per-tier usage caps (quick: 300, deep: 60) enforced server-side in a Firestore transaction.
- Firebase App Check activated (Play Integrity / App Attest in release; debug provider in debug). Enforced on `anthropicProxy`, `redeemReferralCode`, `deleteAccount`.
- `habits` and `habit_completions` collections had no Firestore rules — all habit writes were silently failing in production. Ownership-scoped rules added.
- `deleteAccount` Cloud Function: cascading deletion of Firestore data, Storage files, Supabase identity, Firebase Auth user.
- Firebase Crashlytics wired to `FlutterError.onError` and `PlatformDispatcher.onError`.

### Added

- Full internationalization (TR/EN) — ~270 localized strings; ICU pluralization; flutter_localizations + intl; .arb source files.
- Privacy Policy and Terms of Service screens, linked from register form and profile settings; accessible pre-auth.
- Account deletion in-app flow (two-step confirmation → Cloud Function → cascading data wipe). Required by Apple App Store Guideline 5.1.1(v).
- Vibe Card — weekly wellness summary card (9:16 story format); captured as PNG, shared via share_plus.
- Referral system — invite code generation, server-side redemption, founding-member reward.
- Habit tracking — add/delete habits, daily toggle (atomic via Firestore transaction), weekly stats on Takip screen.
- Daily check-in social proof — anonymous "X people active this week" badge.
- CI/CD — GitHub Actions: analyze + test + format + debug build on every push/PR; signed release AAB on version tags.
- Firestore composite indexes (`habit_completions`, `habits`) checked in to `firestore.indexes.json`.
- Content pipeline: `content/articles.json` + idempotent `seedArticles.js` Admin SDK upsert script.
- Test suite: 43 Flutter tests + 14 Cloud Function tests.

### Changed

- Dark mode now covers every screen including auth.
- `Pressable` widget: disabled state dims to 0.45 opacity with 150 ms animation.
- `toggleCompletion` wrapped in Firestore transaction.
- App initialization: each service wrapped in independent try/catch.
- Android `build.gradle.kts`: conditional release signing.

### Removed

- `name_input_screen.dart`, `onboarding_questions_screen.dart`, `value_props_screen.dart` — consolidated.
- `cupertino_icons` dependency — unused.
- Plaintext credential files.

### Fixed

- Validator error messages now use l10n strings.
- `paywall_screen.dart` missing `mounted` check after async call.
- `signOut()` now surfaces `AuthError` on failure.

### Known Limitations

See [DEPLOYMENT.md](DEPLOYMENT.md#known-limitations-v10) for details.

---

## Previous

No prior releases — this is the first version of ilnd.
