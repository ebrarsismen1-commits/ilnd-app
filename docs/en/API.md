# Cloud Functions API Reference

All functions are Firebase Cloud Functions v2 deployed to the `ilnd-app-8dcbd` project. Base URL pattern:

```
https://<region>-ilnd-app-8dcbd.cloudfunctions.net/<functionName>
```

The client derives sibling function URLs from `AUTH_BRIDGE_URL` via `AppConfig._siblingFunctionUrl()` in [`lib/core/services/app_config.dart`](../../lib/core/services/app_config.dart).

---

## Authentication

Three of four functions require a **Firebase ID token** in the Authorization header:

```
Authorization: Bearer <firebase-id-token>
```

Obtain via:
```dart
final token = await FirebaseAuth.instance.currentUser!.getIdToken();
```

Three functions additionally require a **Firebase App Check token**:
```
X-Firebase-AppCheck: <app-check-token>
```

Obtain via:
```dart
import 'package:ilnd_app/core/services/app_check_headers.dart';
final headers = await appCheckHeaders(); // returns map with X-Firebase-AppCheck
```

---

## `POST /mintFirebaseToken`

Validates a Supabase JWT and returns a Firebase custom token. Used during login to bridge the two auth systems.

**App Check:** Not required (intentional — see [SECURITY.md](SECURITY.md))

**Request body:**
```json
{
  "supabaseToken": "<supabase-jwt>"
}
```

**Response 200:**
```json
{
  "firebaseToken": "<firebase-custom-token>"
}
```

**Response 401:** Invalid or expired Supabase JWT.

**Response 400:** Missing `supabaseToken` field.

**Client usage:** [`lib/features/auth/auth_provider.dart`](../../lib/features/auth/auth_provider.dart) — `_bridgeToFirebase()`

---

## `POST /anthropicProxy`

Proxies AI requests to the Anthropic API. Enforces per-user daily caps server-side. The client cannot override model or token limits.

**App Check:** Required

**Headers:**
```
Authorization: Bearer <firebase-id-token>
X-Firebase-AppCheck: <app-check-token>
Content-Type: application/json
```

**Request body:**
```json
{
  "tier": "quick",
  "messages": [
    { "role": "user", "content": "Bugün nasıl hissediyorum?" }
  ],
  "systemPrompt": "Sen ILND, kişisel bir refah asistanısın."
}
```

**Tier values:**

| Tier | Model | Max Tokens | Daily Limit |
|------|-------|-----------|-------------|
| `quick` | `claude-haiku-4-5` | 512 | 300/day |
| `deep` | `claude-sonnet-4-6` | 1024 | 60/day |

**Response 200:** Anthropic API response object (passed through directly):
```json
{
  "id": "msg_...",
  "type": "message",
  "role": "assistant",
  "content": [{ "type": "text", "text": "..." }],
  "model": "claude-haiku-4-5-20251001",
  "stop_reason": "end_turn",
  "usage": { "input_tokens": 42, "output_tokens": 128 }
}
```

**Response 429:** Daily usage cap exceeded for this tier.

**Response 400:** Missing `messages`, unknown `tier`.

**Response 401:** Invalid or missing Firebase ID token.

**Client usage:** [`lib/core/ilnd/ilnd_service.dart`](../../lib/core/ilnd/ilnd_service.dart) — `_callProxy()`

---

## `POST /redeemReferralCode`

Redeems a referral code for the authenticated user. Atomically:
- Validates the code exists and has not been used by this user
- Blocks self-referral
- Grants the referrer 7 days of premium (stacks with existing `premium_access_until`)
- Marks the redeemer as `founding_member: true`
- Records a `referrals` document

**App Check:** Required

**Headers:**
```
Authorization: Bearer <firebase-id-token>
X-Firebase-AppCheck: <app-check-token>
Content-Type: application/json
```

**Request body:**
```json
{
  "code": "ILND-XXXX"
}
```

**Response 200 (success):**
```json
{ "status": "redeemed" }
```

**Response 200 (already used):**
```json
{ "status": "already-redeemed" }
```

**Response 200 (self-referral):**
```json
{ "status": "self-referral" }
```

**Response 400:** Missing `code` field.

**Response 401:** Invalid or missing Firebase ID token.

**Client usage:** [`lib/core/repositories/referral_repository.dart`](../../lib/core/repositories/referral_repository.dart) — `redeemCode()`

---

## `POST /deleteAccount`

Cascading account deletion. Deletes all user data across Firestore, Storage, Supabase, and Firebase Auth.

**App Check:** Required

**Headers:**
```
Authorization: Bearer <firebase-id-token>
X-Firebase-AppCheck: <app-check-token>
```

**Request body:** Empty (`{}` or no body)

**Deletion order:**
1. `users/{uid}` subcollection documents
2. `user_growth/{uid}` document
3. `referrals` documents where `referred_id == uid`
4. Firebase Storage files under `users/{uid}/`
5. Supabase Auth user (best-effort)
6. Firebase Auth user

**Response 200:**
```json
{ "status": "deleted" }
```

**Response 401:** Invalid or missing Firebase ID token.

**Client usage:** [`lib/features/auth/auth_provider.dart`](../../lib/features/auth/auth_provider.dart) — `deleteAccount()`

---

## Error Response Format

All error responses follow:
```json
{
  "error": "Human-readable error message"
}
```

HTTP status codes:
| Code | Meaning |
|------|---------|
| 200 | Success (including soft-fail states like `already-redeemed`) |
| 400 | Bad request (missing or invalid fields) |
| 401 | Authentication failure |
| 429 | Rate limit exceeded |
| 500 | Unexpected server error |

---

## Testing the API Locally

With the Firebase Emulator running:

```bash
# mintFirebaseToken (no auth required)
curl -X POST http://localhost:5001/ilnd-app-8dcbd/<region>/mintFirebaseToken \
  -H "Content-Type: application/json" \
  -d '{"supabaseToken": "<token>"}'
```

For App-Check-enforced endpoints in tests, see [`functions/test/helpers.js`](../../functions/test/helpers.js) — `getAppCheckHeaderForTests()` uses `admin.appCheck().createToken()` to generate a test token.

---

## Related Documents

- [SECURITY.md](SECURITY.md) — App Check and secret management
- [FIREBASE.md](FIREBASE.md) — Firestore collections written by these functions
- [TESTING.md](TESTING.md) — Cloud Functions test suite
