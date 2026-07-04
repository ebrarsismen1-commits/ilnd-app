# Deployment Guide

## Release Candidate Validation Gates

Before tagging `v1.0.0`, all of the following must pass:

- [ ] TestFlight build validated on at least one iPhone (physical device preferred)
- [ ] Google Play Internal Testing build validated on at least one Android device
- [ ] CI pipeline green on the release commit (analyze, test, build steps)
- [ ] Smoke test checklist completed (see below)
- [ ] Firebase App Check working in production (not debug provider)
- [ ] Crashlytics receiving events (force-crash in TestFlight build to verify)
- [ ] RevenueCat purchase flow verified end-to-end on TestFlight
- [ ] `seedArticles` script run against production Firestore

---

## Pre-Deploy Prerequisites

### Android

1. Generate upload keystore — see [`android/KEYSTORE.md`](../../android/KEYSTORE.md)
2. Set GitHub repo secrets:
   - `ANDROID_KEYSTORE_BASE64` — base64 of the `.jks` file
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`
   - `ANDROID_STORE_PASSWORD`
3. Push a `v1.0.0-rc1` tag — the release workflow produces a signed `.aab`

```bash
git tag v1.0.0-rc1
git push origin v1.0.0-rc1
```

The signed AAB is uploaded as a GitHub Actions artifact. Download it and upload manually to Google Play Console → Internal Testing.

### iOS

1. Create App ID `com.ilnd.ilndApp` in Apple Developer portal
2. Create a Distribution certificate + provisioning profile
3. Open `ios/Runner.xcworkspace` in Xcode
4. Set Team and Signing to the distribution profile
5. `Product → Archive`
6. Upload via Xcode Organizer or Transporter to App Store Connect
7. Add build to TestFlight

### Firebase

```bash
# Deploy Cloud Functions
firebase deploy --only functions

# Deploy Firestore rules + indexes
firebase deploy --only firestore

# Verify in Firebase Console:
# - Crashlytics enabled for the project
# - App Check configured (Play Integrity / App Attest)
# - Register debug App Check token for CI: FIREBASE_APP_CHECK_TEST_APP_ID
```

Set Cloud Function secrets (first time only):
```bash
firebase functions:secrets:set ANTHROPIC_API_KEY
firebase functions:secrets:set SUPABASE_SERVICE_ROLE_KEY
```

### Content

```bash
cd functions
npm install
npm run seed:articles   # populates Firestore 'articles' collection
```

### RevenueCat

1. Create products in App Store Connect + Google Play Console
2. Set up RevenueCat entitlements matching the identifier in `revenue_cat_service.dart`
3. Add RevenueCat API keys to `.env`:
   - `REVENUECAT_API_KEY=appl_...` (iOS)
   - `REVENUECAT_API_KEY=goog_...` (Android)

---

## Environment Setup

Copy `.env.example` to `.env` and fill in:

```ini
# Supabase
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJ...

# Firebase (copy from google-services.json / GoogleService-Info.plist)
FIREBASE_API_KEY=AIzaSy...
FIREBASE_AUTH_DOMAIN=ilnd-app-8dcbd.firebaseapp.com
FIREBASE_PROJECT_ID=ilnd-app-8dcbd
FIREBASE_STORAGE_BUCKET=ilnd-app-8dcbd.appspot.com
FIREBASE_MESSAGING_SENDER_ID=...
FIREBASE_APP_ID=...

# RevenueCat
REVENUECAT_API_KEY=appl_...

# Cloud Functions bridge URL (update after deploying functions)
AUTH_BRIDGE_URL=https://<region>-ilnd-app-8dcbd.cloudfunctions.net/mintFirebaseToken
```

---

## Smoke Test Checklist

After installing a release build on a clean device:

- [ ] App opens without crash (check Crashlytics for init errors)
- [ ] Welcome screen loads; "başla" button navigates to quick-setup
- [ ] Registration creates Supabase account + assigns referral code
- [ ] Login works for an existing account
- [ ] First journal entry triggers ILND AI response
- [ ] Home screen shows mood check-in, today's article, daily intention
- [ ] Chat with ILND responds (tests `anthropicProxy` + App Check end-to-end)
- [ ] Food photo analysis works (tests the food-entry `anthropicProxy` path)
- [ ] Referral code copy + share works
- [ ] Entering a valid referral code as a new user rewards both parties
- [ ] Premium paywall appears after message limit
- [ ] RevenueCat purchase flow completes (use sandbox account)
- [ ] Restore purchases works
- [ ] Privacy Policy and Terms of Service load from profile settings
- [ ] Account deletion wipes all data and returns to login screen
- [ ] Dark mode toggle on home screen changes theme throughout the app
- [ ] App functions offline (journal entries visible; articles fall back to `kArticles`)
- [ ] Crashlytics receives a test event

---

## Rollback Checklist

If a production issue requires immediate rollback:

1. **Flutter app:** Revert to the previous release in Play Console / App Store Connect (both support rolling back within the same version lineage without a new build)
2. **Cloud Functions:** `firebase deploy --only functions` from the previous production commit
3. **Firestore rules:** `firebase deploy --only firestore` from the previous commit; verify via Firebase Console
4. **Firestore data:** No schema migrations in v1.0 — rollback is safe. `user_growth` fields written by old client paths will not conflict with Cloud Function paths
5. **Anthropic API key rotation:** If the proxy endpoint is misbehaving, rotate the key without redeploying the app:
   ```bash
   firebase functions:secrets:set ANTHROPIC_API_KEY
   ```
6. **Content:** If the articles collection has bad data, fix `content/articles.json` and re-run:
   ```bash
   npm run seed:articles -- --prune
   ```

---

## Post-Release Monitoring

Check within the first 24 hours, then daily for the first week:

### Crashlytics
- [ ] Crash rate below 0.1% of sessions
- [ ] No `main()` init failures (FirebaseService, Supabase, RevenueCat)
- [ ] No non-fatal errors from `AuthNotifier`

### Firebase Costs
- [ ] Firestore read/write count within expected range
- [ ] Cloud Function invocation count matches expected usage pattern
- [ ] `anthropicProxy` daily caps being hit at expected rate (some = good; mass hits before cap = potential abuse)
- [ ] `ai_usage` document count growing at expected rate

### RevenueCat
- [ ] Subscription events flowing in RevenueCat dashboard
- [ ] No failed purchase events spike
- [ ] Entitlement grant/revoke cycle working

### Analytics
- [ ] `app_open` events flowing
- [ ] Onboarding events: `onboarding_started`, `onboarding_step_completed`, `time_to_first_value`
- [ ] `streak_extended` and `streak_broken` events appearing
- [ ] Referral events: `referral_link_shared`, `referral_signup_completed`

### App Store / Google Play
- [ ] No policy violation flags
- [ ] Crash rate in Android Vitals within acceptable range
- [ ] User ratings response plan in place

---

## Known Limitations (v1.0)

See [`CHANGELOG.md`](../../CHANGELOG.md#known-limitations) for the full list.

1. Dark mode requires per-call-site color overrides for stock Material widgets
2. `isPremiumProvider` seeded from local SharedPreferences (rooted device risk, bounded)
3. Cloud Functions emulator tests require `FIREBASE_APP_CHECK_TEST_APP_ID`
4. Longest-streak is per-device only
5. `skeleton.dart` is dead code — flagged for v1.1
6. iOS ATT prompt decision pending
7. `mintFirebaseToken` has no per-UID rate limit
8. Store listing assets (screenshots, description) not yet created

---

## Related Documents

- [INSTALLATION.md](INSTALLATION.md) — local setup
- [FIREBASE.md](FIREBASE.md) — Firebase service configuration
- [SECURITY.md](SECURITY.md) — secrets and App Check
- [APP_STORE_CHECKLIST.md](APP_STORE_CHECKLIST.md) — store submission checklist
