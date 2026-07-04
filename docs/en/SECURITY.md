# Security Guide

## Threat Model

ilnd is a consumer wellness app. The primary security concerns are:

1. **Premium bypass** — users granting themselves free premium access
2. **API key exposure** — Anthropic key leaking into the client binary
3. **Data isolation** — one user reading or modifying another user's data
4. **AI cost abuse** — users exceeding their daily AI request allowance
5. **Account takeover** — unauthorized deletion or exfiltration of user data

All five are addressed in the current architecture.

---

## Critical Fixes (v1.0)

### 1. Premium Self-Grant (CRITICAL — Fixed)

**Pre-fix:** `user_growth` was world-writable. Any authenticated user could call `db.collection('user_growth').doc(uid).update({founding_member: true, premium_access_until: <far future>})` directly from the client.

**Fix:** Firestore rules now deny all client writes to `founding_member`, `premium_access_until`, and `referred_by_code`. These fields are written exclusively by the `redeemReferralCode` Cloud Function running under the Firebase Admin SDK.

```javascript
// firestore.rules — user_growth
allow create: if request.auth != null
  && request.auth.uid == userId
  && request.resource.data.founding_member == false
  && request.resource.data.premium_access_until == null
  && request.resource.data.referred_by_code == null;

allow update: if false;  // Admin SDK only
allow delete: if false;
```

### 2. Anthropic API Key in Client Binary (CRITICAL — Fixed)

**Pre-fix:** The key was passed via `--dart-define=ANTHROPIC_API_KEY=sk-ant-...` and compiled into the app binary. It could be extracted with standard APK/IPA analysis tools.

**Fix:** Key removed from all client-side code. All AI requests go through `anthropicProxy` Cloud Function, which holds the key in Firebase Secret Manager. The client receives only the AI response — never the key.

---

## Firestore Security Rules

Every collection is access-controlled. Key rules:

| Collection | Read | Write |
|-----------|------|-------|
| `users/{uid}` | Owner only | Owner only |
| `users/{uid}/journal_entries` | Owner only | Owner only |
| `habits` | Owner only (userId match) | Owner only |
| `habit_completions` | Owner only | Owner only |
| `user_growth` | Owner only | Create (restricted fields), no update/delete |
| `referrals` | — | Admin SDK only |
| `articles` | Any authenticated | Admin SDK only |
| `ai_usage` | Owner only | Cloud Function (Admin SDK) |

"Owner only" means `request.auth.uid == resource.data.userId` (or `== userId` path param).

Verify rules locally:
```bash
firebase emulators:start
# Rules are enforced in the emulator exactly as in production
```

---

## Firebase App Check

App Check verifies that requests come from the genuine app binary, not a script or modified APK.

**Configuration:**

| Platform | Provider (Release) | Provider (Debug) |
|----------|-------------------|-----------------|
| Android | Play Integrity | Debug provider |
| iOS | App Attest | Debug provider |

Enforced on:
- `anthropicProxy` — AI request proxy
- `redeemReferralCode` — referral redemption
- `deleteAccount` — cascading account deletion

**Not enforced on** `mintFirebaseToken` — intentionally, to avoid locking users out of login if device attestation fails during rollout.

App Check activation is in [`lib/main.dart`](../../lib/main.dart):

```dart
await FirebaseAppCheck.instance.activate(
  androidProvider: kReleaseMode
      ? AndroidProvider.playIntegrity
      : AndroidProvider.debug,
  appleProvider: kReleaseMode
      ? AppleProvider.appAttest
      : AppleProvider.debug,
);
```

---

## AI Usage Caps

Daily limits enforced in `anthropicProxy` via Firestore transaction:

```javascript
// functions/index.js
const TIER_CONFIG = {
  quick: { model: 'claude-haiku-4-5', maxTokens: 512, dailyLimit: 300 },
  deep:  { model: 'claude-sonnet-4-6', maxTokens: 1024, dailyLimit: 60 },
};
```

The transaction reads and increments `ai_usage/{uid}/{tier}/{today}` atomically before forwarding the request to Anthropic. If the count would exceed the daily limit, the function returns `429 Too Many Requests`. The client cannot bypass this by supplying a different model or token count — both are set server-side from the tier config.

---

## Secrets Management

| Secret | Storage | Access |
|--------|---------|--------|
| Anthropic API key | Firebase Secret Manager | `anthropicProxy` function only |
| Supabase service role key | Firebase Secret Manager | `deleteAccount` function only |
| Supabase anon key | Client `.env` / `--dart-define` | Intentionally public (RLS enforced) |
| Android keystore | GitHub Actions secret (base64) | Release workflow only |

**Never commit:**
- `.env` files
- `google-services.json`
- `GoogleService-Info.plist`
- `*.keystore` / `*.jks` / `key.properties`

All are listed in [`.gitignore`](../../.gitignore).

Set Cloud Function secrets:
```bash
firebase functions:secrets:set ANTHROPIC_API_KEY
firebase functions:secrets:set SUPABASE_SERVICE_ROLE_KEY
```

---

## Account Deletion

The `deleteAccount` Cloud Function performs cascading deletion:

1. All Firestore documents under `users/{uid}/`
2. `user_growth/{uid}` document
3. All `referrals` documents where `referred_id == uid`
4. Firebase Storage files under `users/{uid}/`
5. Supabase Auth user (best-effort — failure logged but does not block)
6. Firebase Auth user

Required by [Apple App Store Guideline 5.1.1(v)](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage).

---

## Crashlytics Privacy

Crashlytics is disabled in debug mode:

```dart
await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
```

No PII is intentionally sent to Crashlytics. Stack traces and device metadata are collected only in release builds.

---

## Vulnerability Reporting

If you discover a security vulnerability, contact the project maintainer directly (do not open a public GitHub issue). Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact assessment

---

## Known Limitations

- **mintFirebaseToken rate limiting:** No per-IP or per-UID rate limit. The `maxInstances: 10` Cloud Function cap is a blunt ceiling. At scale, consider adding Cloud Armor or a per-UID request quota.
- **Entitlement local cache:** `isPremiumProvider` reads from SharedPreferences synchronously. A rooted device can tamper with this flag. The server-side `anthropicProxy` daily cap still applies, bounding cost exposure.
- **Multi-device streak:** Longest streak is stored in SharedPreferences (device-local). No security implication, but a UX inconsistency.

---

## Related Documents

- [FIREBASE.md](FIREBASE.md) — Firestore rules and indexes
- [API.md](API.md) — Cloud Functions authentication details
- [DEPLOYMENT.md](DEPLOYMENT.md) — App Check configuration in production
