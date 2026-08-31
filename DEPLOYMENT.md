# Deployment Guide — v1.0.0

## Release Candidate Validation Gates

Before tagging `v1.0.0`, all of the following must pass:

- [ ] TestFlight build validated on at least iPhone (physical device preferred)
- [ ] Google Play Internal Testing build validated on at least one Android device
- [ ] CI pipeline green on the release commit (analyze, test, build steps)
- [ ] Smoke test checklist completed (see below)
- [ ] Firebase App Check working in production (not debug provider)
- [ ] Crashlytics receiving events (force-crash in TestFlight build to verify)
- [ ] RevenueCat purchase flow verified end-to-end on TestFlight
- [ ] seedArticles script run against production Firestore

---

## Pre-Deploy Prerequisites

### Android
1. Generate upload keystore — see `android/KEYSTORE.md`
2. Set GitHub repo secrets:
   - `ANDROID_KEYSTORE_BASE64` (base64 of the .jks file)
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`
   - `ANDROID_STORE_PASSWORD`
3. Push a `v1.0.0-rc1` tag — the release workflow produces a signed .aab

### iOS
1. Create an App ID `com.ilnd.ilndApp` in Apple Developer portal
2. Create a Distribution certificate + provisioning profile
3. Sign the app in Xcode (`Product → Archive`)
4. Upload via Xcode Organizer or Transporter

### Firebase
1. `firebase deploy --only functions` — deploys all Cloud Functions
2. `firebase deploy --only firestore` — deploys rules + indexes
   (the `ai_usage` rule is required for the app to show remaining free-tier
   quota; without it the counter reads permission-denied and the paywall only
   appears after the server's 429)
3. Verify Crashlytics is enabled in Firebase console for the project
4. Verify App Check is configured (Play Integrity / App Attest) in console
5. Register debug App Check token for CI (`FIREBASE_APP_CHECK_TEST_APP_ID`)

### Supabase (password reset e-mail)

The "Reset Password" e-mail template **must** link straight into the app with a
token hash. The default `{{ .ConfirmationURL }}` template sends the user through
Supabase's own `/auth/v1/verify` endpoint, which burns the one-time token on the
first HTTP GET. Mail scanners and corporate "safe links" services follow that URL
before the user does, so by the time the user clicks, the token is gone and the
app receives `?error=access_denied&error_code=otp_expired`. This happened in
production on 2026-08-31.

Dashboard → Authentication → Emails → **Reset Password**, set the link to:

```html
<a href="https://ilnd-app-8dcbd.web.app/?token_hash={{ .TokenHash }}&type=recovery">
  sifreni sifirla
</a>
```

With this template the link points at our own page and the token is consumed only
when the app calls `verifyOTP` (see `recoveryTokenHashFrom` and
`_verifyRecoveryLink` in `lib/features/auth/auth_provider.dart`). A scanner that
opens the URL consumes nothing.

Notes:

- The app handles both templates. Until this change is made the old flow stays
  in effect, so shipping the code first is safe.
- Password reset now completes **on the web**. A mobile user opens the link in a
  browser, sets the new password there, and signs into the app with it.
- Do not change the **Confirm signup** template: account confirmation still uses
  `{{ .ConfirmationURL }}` plus the `com.ilnd.app://login-callback` deep link.
- Verify after changing: request a reset, then check Dashboard → Logs → Auth.
  There must be exactly one `/verify` call, made when you click the link.

### Content
```bash
cd functions
npm install
npm run seed:articles   # populates Firestore 'articles' collection
npm run seed:movement   # populates Firestore 'movement_programs' collection
```
Movement programs (ADR-0004) are optional: `content/movementPrograms.json`
ships empty on purpose, and the Explore shelf stays hidden until at least one
program has a session with a `videoUrl`. Videos belong in Firebase Storage
under `movement/{programId}/{sessionId}.mp4`; put that object's download URL
in the JSON. The schema is documented at the top of
`functions/scripts/seedMovementPrograms.js`.

### RevenueCat
1. Create products in App Store Connect + Google Play Console
2. Set up RevenueCat entitlements matching `kIlndPlusPremium` (or update the
   offering ID in `revenue_cat_service.dart`)
3. Add RevenueCat API key to `.env` (`REVENUECAT_API_KEY`)
4. **Add the RevenueCat *secret* key to `functions/.env`
   (`REVENUECAT_SECRET_KEY`) before selling subscriptions.** The weekly free
   tier is enforced server-side per account (`anthropicProxy`); without this
   key the server cannot see store subscriptions, so paying subscribers would
   hit the free-tier wall. The client binds the subscription to the account
   via `Purchases.logIn(uid)` (`RevenueCatService.identify`), which is what
   makes the server-side lookup by uid possible.

---

## Web Hosting

```bash
flutter build web --release --dart-define-from-file=.env
firebase deploy --only hosting --project ilnd-app-8dcbd
```

`--dart-define-from-file=.env` is NOT optional. Every value in `AppConfig`
falls back to an empty string, so a build without it compiles cleanly, passes
analysis, deploys successfully, and then fails silently at runtime: Supabase
never initializes, no session is restored, and every user is redirected to the
login screen. Nothing in the build output warns about this.

Verify before deploying:

```bash
grep -c "supabase.co" build/web/main.dart.js
```

Anything other than `1` means the config was not baked in. Do not deploy.

Known gap: `.env` currently has no `RECAPTCHA_SITE_KEY` (App Check on web) or
`REVENUECAT_API_KEY` (paywall). Both fall back to empty, so App Check tokens
fail on web and the paywall stays inert until they are added.

## Environment Setup

Copy `.env.example` to `.env` and fill in:
```
ANTHROPIC_API_KEY=sk-ant-...         # set as Firebase Secret, not here
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
FIREBASE_API_KEY=AIza...
FIREBASE_AUTH_DOMAIN=...
FIREBASE_PROJECT_ID=...
FIREBASE_STORAGE_BUCKET=...
FIREBASE_MESSAGING_SENDER_ID=...
FIREBASE_APP_ID=...
REVENUECAT_API_KEY=appl_...
AUTH_BRIDGE_URL=https://<region>-<project-id>.cloudfunctions.net/mintFirebaseToken
```

Set Cloud Function secrets:
```bash
firebase functions:secrets:set ANTHROPIC_API_KEY
firebase functions:secrets:set SUPABASE_SERVICE_ROLE_KEY
```

---

## Smoke Test Checklist

After installing a release build on a clean device:

- [ ] App opens without crash (check Crashlytics for any init errors)
- [ ] Welcome screen loads; "başla" button navigates to quick-setup
- [ ] Registration creates Supabase account + assigns referral code
- [ ] Login works for existing account
- [ ] First journal entry triggers ILND AI response
- [ ] Home screen shows mood check-in, today's article, daily intention
- [ ] Chat with ILND responds (checks anthropicProxy + App Check end-to-end)
- [ ] Food photo analysis works (checks yemek_ekle anthropicProxy path)
- [ ] Referral code copy + share works
- [ ] Entering a valid referral code as a new user rewards both parties
- [ ] Premium paywall appears after message limit
- [ ] RevenueCat purchase flow completes (use sandbox account)
- [ ] Restore purchases works
- [ ] Privacy Policy and Terms of Service load from profile settings
- [ ] Account deletion wipes all data and returns to login screen
- [ ] Dark mode toggle on home screen changes theme throughout the app
- [ ] App functions offline (journal entry shows, articles fallback to kArticles)
- [ ] Crashlytics receives a test event (force crash via hidden gesture if available)

---

## Rollback Checklist

If a production issue requires immediate rollback:

1. **Flutter app**: revert to the previous tag in Play Console / App Store
   Connect (both support rolling back to a previous release within the same
   version lineage without a new build)
2. **Cloud Functions**: `firebase deploy --only functions` from the previous
   commit that was in production
3. **Firestore rules**: `firebase deploy --only firestore` from the previous
   commit; verify rules are back to expected state via Firebase console
4. **Firestore data**: no schema migrations in v1.0 — rollback is safe.
   `user_growth.founding_member` and `premium_access_until` written by the
   old `redeemCode` client path will remain; the new Cloud Function path
   doesn't conflict.
5. **Anthropic API key**: if the proxy endpoint is misbehaving, the key is
   in Firebase Secret Manager — rotate via `firebase functions:secrets:set
   ANTHROPIC_API_KEY` without redeploying the app.
6. **Content**: if the articles collection has bad data, re-run
   `npm run seed:articles` with corrected `content/articles.json`.

---

## Post-Release Monitoring Checklist

Check these within the first 24 hours after launch, and daily for the first week:

### Crashlytics
- [ ] No crash rate spike above 0.1% of sessions (Firebase console)
- [ ] Check for any `main()` init failures (FirebaseService, Supabase, RevenueCat)
- [ ] Check for any non-fatal errors from AuthNotifier (signIn/signUp/deleteAccount)

### Firebase Performance / Costs
- [ ] Firestore read/write count within expected range (not a runaway query)
- [ ] Cloud Function invocation count matches expected user count × usage pattern
- [ ] `anthropicProxy` daily usage caps being hit at expected rate (some = good;
  mass-hit before daily cap = potential abuse)
- [ ] `ai_usage` collection document count growing at expected rate (1 doc/user/day)

### RevenueCat
- [ ] Subscription events flowing in RevenueCat dashboard
- [ ] No failed purchase events spike
- [ ] Entitlement grant/revoke cycle working (check a test purchase)

### Analytics (Firebase Analytics)
- [ ] `app_open` events flowing
- [ ] `onboarding_started`, `onboarding_step_completed`, `time_to_first_value`
  events present for new installs
- [ ] `streak_extended` and `streak_broken` events appearing
- [ ] `referral_link_shared` and `referral_signup_completed` events after
  referral-driven installs

### App Store / Google Play
- [ ] No policy violation flags in App Store Connect / Play Console
- [ ] User ratings flowing (set up responses if negative reviews appear)
- [ ] Crash rate in Play Console's Android Vitals within acceptable range

---

## Known Limitations (v1.0)

1. **Dark mode — Material widgets**: `MaterialApp` applies `AppTheme.light`
   only. `ElevatedButton`, `AlertDialog`, `TextButton`, `TextField` require
   explicit palette color overrides per call site. Comprehensive fix
   (`ThemeData.dark()` + `themeMode` wiring) is scoped to v1.1.

2. **Entitlement seeding from local cache**: `isPremiumProvider` reads a
   SharedPreferences flag synchronously on startup, then syncs from RevenueCat
   asynchronously. On a rooted device the local flag can be tampered, but the
   server-side `anthropicProxy` daily cap still applies regardless.

3. **Cloud Functions emulator tests + App Check**: The three App-Check-enforced
   functions' emulator tests require `FIREBASE_APP_CHECK_TEST_APP_ID` in CI.
   Without it, those tests will 401. Currently unverified — see README.

4. **Longest-streak per-device**: `longestStreakProvider` stores in
   SharedPreferences locally; multi-device users see different values.

5. **`skeleton.dart` dead code**: `SkeletonCard`/`SkeletonBox` are never
   imported. The widget is correct and tested but unused; slated for removal
   or adoption in v1.1.

6. **iOS App Tracking Transparency**: Firebase Analytics is integrated.
   Whether it constitutes "tracking" under Apple's ATT definition requires a
   product decision before submitting to App Store (either confirm first-party
   only and reflect in App Privacy answers, or add ATT prompt).

7. **mintFirebaseToken rate limiting**: No per-uid or per-IP rate limit; the
   global `maxInstances: 10` is a blunt cap. At scale, add App Check
   enforcement (current design choice was to leave it unenforced to avoid
   login lockouts).

8. **Store listing assets**: no screenshots, feature graphic, app description
   draft, or App Privacy questionnaire answers exist yet.
