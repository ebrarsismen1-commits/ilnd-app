# Firebase Guide

## Project

- **Project ID:** `ilnd-app-8dcbd`
- **Project config:** [`.firebaserc`](../../.firebaserc), [`firebase.json`](../../firebase.json)
- **Services in use:** Auth, Firestore, Cloud Functions, Storage, App Check, Crashlytics, Analytics

---

## Firestore Collections

### `users/{uid}`

Top-level user document created at registration.

| Field | Type | Description |
|-------|------|-------------|
| `onboarding_complete` | bool | Set to `true` after first-entry screen |
| `display_name` | string | User's name from quick-setup |

### `users/{uid}/journal_entries/{entryId}`

| Field | Type | Description |
|-------|------|-------------|
| `text` | string | User's journal text |
| `aiResponse` | string | ILND AI response |
| `mood` | string | Selected mood emoji/label |
| `createdAt` | timestamp | Server timestamp |

### `users/{uid}/chat_messages/{msgId}`

| Field | Type | Description |
|-------|------|-------------|
| `role` | string | `"user"` or `"assistant"` |
| `content` | string | Message text |
| `createdAt` | timestamp | Server timestamp |

### `habits/{habitId}`

Top-level collection (not subcollection) for cross-user indexing. Ownership enforced by Firestore rules.

| Field | Type | Description |
|-------|------|-------------|
| `userId` | string | Owner UID |
| `name` | string | Habit name |
| `createdAt` | timestamp | Server timestamp |

### `habit_completions/{completionId}`

| Field | Type | Description |
|-------|------|-------------|
| `userId` | string | Owner UID |
| `habitId` | string | Reference to `habits/{habitId}` |
| `date` | string | ISO date `YYYY-MM-DD` |

**Note:** `toggleCompletion` is wrapped in a Firestore transaction — reads the document, then atomically deletes or creates. No race condition on double-tap.

### `user_growth/{uid}`

Referral and premium status. **Client write-only for create** (restricted fields). Updates are Admin SDK only.

| Field | Type | Description |
|-------|------|-------------|
| `referral_code` | string | User's invite code (e.g., `ILND-XXXX`) |
| `referred_by_code` | string \| null | Code used when this user signed up |
| `founding_member` | bool | `true` after successful referral redemption |
| `premium_access_until` | timestamp \| null | Premium expiry (null = no premium) |

### `referrals/{referralId}`

Written exclusively by `redeemReferralCode` Cloud Function.

| Field | Type | Description |
|-------|------|-------------|
| `referrer_id` | string | UID of the user who shared the code |
| `referred_id` | string | UID of the new user who redeemed it |
| `redeemed_at` | timestamp | When redemption occurred |

### `ai_usage/{uid}/{tier}/{date}`

Daily AI usage tracking. Written by `anthropicProxy` in a transaction.

| Field | Type | Description |
|-------|------|-------------|
| `count` | int | Number of requests today |

`tier` is `"quick"` or `"deep"`. `date` is ISO date `YYYY-MM-DD`.

### `articles/{articleId}`

Content collection. Populated by [`functions/scripts/seedArticles.js`](../../functions/scripts/seedArticles.js).

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Stable slug (e.g., `matcha-latte`) |
| `title` | string | Article title |
| `body` | string | Article body text |
| `category` | string | Filter category |
| `readTimeMinutes` | int | Estimated read time |

### `daily_checkins/{date}`

Anonymous active-user counter for social proof widget.

| Field | Type | Description |
|-------|------|-------------|
| `activeCount` | int | Number of users active this week |

---

## Composite Indexes

Defined in [`firestore.indexes.json`](../../firestore.indexes.json). These are required for the queries the app makes — without them, Firestore returns an error with a link to create the index manually.

| Collection | Fields | Order |
|-----------|--------|-------|
| `habit_completions` | `userId`, `date` | ASC, ASC |
| `habits` | `userId`, `createdAt` | ASC, ASC |

Deploy indexes:
```bash
firebase deploy --only firestore:indexes
```

---

## Security Rules

Defined in [`firestore.rules`](../../firestore.rules). Deploy:

```bash
firebase deploy --only firestore:rules
```

Key rules:
- All collections require `request.auth != null`
- User-owned data requires `request.auth.uid == resource.data.userId`
- `user_growth` create: allowed with `founding_member == false`, `premium_access_until == null`, `referred_by_code == null`
- `user_growth` update/delete: `if false` (Admin SDK only)
- `referrals` all writes: `if false` (Admin SDK only)
- `articles` write: `if false` (Admin SDK only)

---

## Cloud Functions Deployment

```bash
firebase deploy --only functions
```

Deploy individual function:
```bash
firebase deploy --only functions:mintFirebaseToken
```

Set secrets before first deploy:
```bash
firebase functions:secrets:set ANTHROPIC_API_KEY
firebase functions:secrets:set SUPABASE_SERVICE_ROLE_KEY
```

---

## Emulator Configuration

Ports defined in [`firebase.json`](../../firebase.json):

```json
{
  "emulators": {
    "auth": { "port": 9099 },
    "firestore": { "port": 8080 },
    "functions": { "port": 5001 },
    "storage": { "port": 9199 },
    "ui": { "enabled": true, "port": 4000 }
  }
}
```

Start all emulators:
```bash
firebase emulators:start
```

The Flutter app automatically connects to emulators when `kDebugMode` is true (configured in `main.dart`).

---

## App Check Configuration

In Firebase Console → App Check:

1. **Android:** Register with Play Integrity provider. Download the debug token for CI.
2. **iOS:** Register with App Attest provider. Download the debug token for Simulator.
3. Add debug tokens as environment variables for development:
   - `FIREBASE_APP_CHECK_TEST_APP_ID` for CI/CD

Enforced functions (must have valid token or requests fail with 401):
- `anthropicProxy`
- `redeemReferralCode`
- `deleteAccount`

---

## Crashlytics

Enabled automatically in release mode by `lib/main.dart`. To verify Crashlytics is receiving events:

1. Build a release APK or TestFlight build
2. Force a crash (add a temporary `throw Exception('test crash')` behind a hidden gesture)
3. Open the app, trigger the crash, reopen the app
4. Check Firebase Console → Crashlytics within 5 minutes

Debug mode: `setCrashlyticsCollectionEnabled(false)` — no events sent.

---

## Content Seeding

```bash
cd functions
npm run seed:articles
# Options:
# --prune   Delete Firestore articles not present in articles.json
```

Requires Firebase CLI authenticated with a service account that has Firestore write access. In production, use a service account key or `firebase login` with an account that has `Cloud Datastore User` role.

---

## Related Documents

- [API.md](API.md) — Cloud Functions request/response format
- [SECURITY.md](SECURITY.md) — Firestore rules and App Check details
- [DEPLOYMENT.md](DEPLOYMENT.md) — production deploy checklist
