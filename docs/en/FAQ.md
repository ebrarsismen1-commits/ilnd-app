# Frequently Asked Questions

## General

### What is ilnd?

ilnd ("iyi hisset, iyi yaşa" — feel good, live well) is a Gen-Z wellness journaling app. It combines a daily journaling habit with an AI companion (ILND) that learns from your entries and responds with personalized insights. The app also tracks habits, nutrition, and weekly wellness trends via the Vibe Card feature.

### What platforms does ilnd support?

iOS 16+ and Android 8+ (API 26). Flutter renders the same UI on both platforms.

### What language is the app in?

The app ships with full Turkish (TR) and English (EN) support. The active locale follows the device language setting, with TR as the default for unsupported locales.

### Is ilnd free?

The core journaling and habit tracking features are free. The premium tier (ilnd+) unlocks unlimited AI conversations and deep-tier AI responses. Premium is granted via RevenueCat subscription or a referral reward.

---

## Technical

### Why does the app use both Supabase and Firebase?

Supabase handles authentication UX (login/signup forms, session management). Firebase powers Firestore (the database), Cloud Functions (server-side logic), and App Check (request attestation). Bridging them is a `mintFirebaseToken` Cloud Function that converts a Supabase JWT into a Firebase custom token. This lets Firestore security rules use Firebase Auth's `request.auth.uid` for ownership checks.

### Why is the Anthropic API key not in the app binary?

An API key in the client binary can be extracted from any APK or IPA using standard analysis tools. The key is stored in Firebase Secret Manager and accessed only by the `anthropicProxy` Cloud Function. The client sends messages and receives responses — it never sees the key.

### How does the referral system work?

Each user gets a unique referral code in `user_growth/{uid}.referral_code`. When a new user redeems a code, the `redeemReferralCode` Cloud Function:
1. Validates the code and blocks self-referral
2. Grants the referrer 7 days of premium (stacks with existing premium)
3. Marks the new user as a founding member
4. Records the referral in Firestore

The client cannot manipulate premium status directly — it's all server-side.

### How are AI usage limits enforced?

The `anthropicProxy` Cloud Function increments a counter in `ai_usage/{uid}/{tier}/{date}` inside a Firestore transaction before forwarding the request to Anthropic. If the count would exceed the daily limit (300 for quick tier, 60 for deep tier), the function returns 429. The client cannot override the model or limits — both are set server-side.

### What happens to user data on account deletion?

The `deleteAccount` Cloud Function cascades:
1. All Firestore documents under `users/{uid}/`
2. `user_growth/{uid}` document
3. `referrals` documents for this user
4. Firebase Storage files under `users/{uid}/`
5. Supabase Auth user (best-effort)
6. Firebase Auth user

This meets Apple App Store Guideline 5.1.1(v).

### Why is `mintFirebaseToken` not protected by App Check?

App Check verifies the request comes from a genuine app binary. If App Check enforcement fails during a rollout (device attestation issues, new device types, etc.), users would be locked out of login entirely with no way to recover. The function validates the Supabase JWT instead — this is sufficient for the login entry point.

### Why does the app use a custom palette instead of `ThemeData.dark()`?

The dark mode requirement came after the initial architecture. Retrofitting `ThemeData.dark()` would require updating every `MaterialApp`-level theme configuration and testing every screen. The custom `AppPalette` + `paletteProvider` approach achieved dark mode coverage faster. The `ThemeData.dark()` migration is planned for v1.1.

---

## Development

### How do I add a new localized string?

1. Add the key to `lib/l10n/app_tr.arb` (Turkish template)
2. Add the same key to `lib/l10n/app_en.arb` (English translation)
3. Run `flutter gen-l10n`
4. Use `AppLocalizations.of(context)!.yourKey` in widgets

### How do I reset my AI usage counter during development?

Open the Emulator UI at [http://localhost:4000](http://localhost:4000), navigate to Firestore, and delete the document at `ai_usage/{your-uid}/quick/{today}` or `ai_usage/{your-uid}/deep/{today}`.

### Why does `pumpAndSettle()` time out in widget tests?

`AnimatedBackground` uses an infinite animation controller. `pumpAndSettle()` waits until all animations settle — which never happens for an infinite animation. Use `await tester.pump()` + `await tester.pump(Duration(milliseconds: 100))` instead.

### How do I run only the Cloud Function tests?

```bash
firebase emulators:start &   # or in a separate terminal
cd functions
npm test
```

### Can I use the app without setting up Firebase?

No. Firebase Firestore is the primary database. Without it, journal entries, habits, and user growth data cannot be stored or retrieved.

---

## Content

### How are articles managed?

Articles are stored in `content/articles.json` and uploaded to Firestore using the seed script:
```bash
cd functions
npm run seed:articles
```

The app also includes a `kArticles` constant in Dart that serves as an offline fallback when Firestore is unreachable.

### How do I add a new article?

1. Add an entry to `content/articles.json` with a unique `id` field
2. Run `npm run seed:articles` to push it to Firestore
3. The app will display it immediately — no app update required

### What article categories exist?

Categories are free-form strings in `articles.json`. The Explore screen filters by category. Any string is valid — use consistent casing to ensure filter chips work correctly.

---

## Deployment

### How do I get a signed Android build?

Push a version tag (e.g., `v1.0.0`). The GitHub Actions release workflow builds and signs the AAB using the keystore secrets configured in the repo. The signed AAB is uploaded as a workflow artifact.

### What Firebase secrets need to be set before deploying functions?

```bash
firebase functions:secrets:set ANTHROPIC_API_KEY
firebase functions:secrets:set SUPABASE_SERVICE_ROLE_KEY
```

Both must be set before the first `firebase deploy --only functions`.

### Is it safe to run `seedArticles.js` multiple times?

Yes. The script performs idempotent upserts keyed on the `id` field. Running it twice produces the same result as running it once.

---

## Related Documents

- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — error diagnosis
- [INSTALLATION.md](INSTALLATION.md) — local setup
- [ARCHITECTURE.md](ARCHITECTURE.md) — system design
