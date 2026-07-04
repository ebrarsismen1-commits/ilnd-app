# Architecture — ilnd

## Overview

ilnd is a Flutter mobile application for Gen-Z wellness journaling. It uses a dual-backend architecture: Supabase handles authentication UX, Firebase handles all persistent data and server-side logic. An AI layer (Anthropic Claude) is exposed exclusively through a Cloud Function proxy — the API key never touches the client binary.

```
┌─────────────────────────────────────────────────────────────────┐
│                         Flutter Client                          │
│                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
│  │  Riverpod │  │ go_router│  │ AppTheme │  │ AppLocaliz.  │  │
│  │  (state) │  │  (nav)  │  │(palette) │  │  (TR / EN)   │  │
│  └──────────┘  └──────────┘  └──────────┘  └───────────────┘  │
└───────────────────┬──────────────────────────────┬─────────────┘
                    │                              │
          ┌─────────▼────────┐          ┌──────────▼──────────┐
          │   Supabase Auth  │          │  Firebase Firestore  │
          │  (email/password)│          │  (all app data)     │
          └─────────┬────────┘          └──────────┬──────────┘
                    │  JWT                         │
          ┌─────────▼────────────────────────────┐ │
          │  Cloud Functions (Firebase v2/Node 20)│ │
          │                                      │ │
          │  mintFirebaseToken ◄──── Supabase JWT │ │
          │  anthropicProxy   ──────────────────────┘
          │  redeemReferralCode                  │
          │  deleteAccount                       │
          └──────────────────────┬───────────────┘
                                 │
                    ┌────────────▼──────────┐
                    │  Anthropic API        │
                    │  (haiku-4-5 / sonnet) │
                    └───────────────────────┘
```

## Dual Auth System

Supabase provides the login/signup UI and session management. Firebase powers Firestore security rules. Bridging them:

1. User authenticates with Supabase → receives Supabase JWT
2. Client calls `mintFirebaseToken` Cloud Function with the JWT
3. Cloud Function validates JWT via Supabase JWKS endpoint
4. Returns a Firebase custom token
5. Client signs into Firebase Auth with this token
6. All subsequent Firestore reads/writes use Firebase Auth's `request.auth.uid`

```
User → Supabase.signIn() → supabase_session
     → mintFirebaseToken(supabase_jwt)
     → firebase_custom_token
     → FirebaseAuth.signInWithCustomToken()
     → firestore_rules: request.auth.uid == resource.data.userId ✓
```

See [`lib/features/auth/auth_provider.dart`](../../lib/features/auth/auth_provider.dart) and [`functions/index.js`](../../functions/index.js).

## State Management

All state is managed with **Riverpod 2.6.1**. Provider types by use case:

| Type | Used For | Example |
|------|----------|---------|
| `Provider` | Singleton services | `ilndServiceProvider`, `ilndLearnerProvider` |
| `StateNotifierProvider` | Mutable state | `authNotifierProvider`, `themeModeProvider` |
| `FutureProvider` | One-shot async | `userGrowthProvider`, `articleProvider` |
| `StreamProvider` | Real-time Firestore | `habitsProvider`, `habitCompletionsProvider` |

State is never passed as constructor arguments through the widget tree — always read via `ref.watch` / `ref.read`.

## Navigation

**go_router 14.x** with a `_RouterNotifier` that rebuilds on auth and onboarding state changes:

```
/splash
/auth/login
/auth/register
/onboarding/welcome
/onboarding/quick-setup
/onboarding/first-entry
/home  (shell route with bottom nav)
  /chat
  /takip
  /ekle
  /profile
/explore/article/:id
/legal/privacy
/legal/terms
/referral
/vibe-card
/paywall
```

Routes `/legal/privacy` and `/legal/terms` bypass the auth guard — accessible before login.

See [`lib/core/router/app_router.dart`](../../lib/core/router/app_router.dart).

## Firestore Data Model

All user data lives under `users/{uid}/` subcollections plus top-level collections for cross-user queries.

```
users/{uid}
  onboarding_complete: bool
  display_name: string

users/{uid}/journal_entries/{entryId}
  text: string
  aiResponse: string
  mood: string
  createdAt: timestamp

users/{uid}/chat_messages/{msgId}
  role: "user" | "assistant"
  content: string
  createdAt: timestamp

habits/{habitId}                          ← top-level (userId scoped by rules)
  userId: string
  name: string
  createdAt: timestamp

habit_completions/{completionId}          ← top-level (userId scoped)
  userId: string
  habitId: string
  date: string  (YYYY-MM-DD)

user_growth/{uid}
  referral_code: string
  referred_by_code: string | null
  founding_member: bool
  premium_access_until: timestamp | null

referrals/{referralId}
  referrer_id: string
  referred_id: string
  redeemed_at: timestamp

ai_usage/{uid}/quick/{date}
  count: int

ai_usage/{uid}/deep/{date}
  count: int

articles/{articleId}
  id: string
  title: string
  body: string
  category: string
  readTimeMinutes: int

daily_checkins/{date}
  activeCount: int
```

Composite indexes are defined in [`firestore.indexes.json`](../../firestore.indexes.json):
- `habit_completions`: `userId ASC` + `date ASC`
- `habits`: `userId ASC` + `createdAt ASC`

## Cloud Functions

All four functions live in [`functions/index.js`](../../functions/index.js):

| Function | Auth Required | App Check | Secret |
|----------|--------------|-----------|--------|
| `mintFirebaseToken` | Supabase JWT in body | No (intentional) | — |
| `anthropicProxy` | Firebase ID token | Yes | `ANTHROPIC_API_KEY` |
| `redeemReferralCode` | Firebase ID token | Yes | — |
| `deleteAccount` | Firebase ID token | Yes | `SUPABASE_SERVICE_ROLE_KEY` |

`mintFirebaseToken` is exempt from App Check because it is the login entry point — enforcing App Check here risks locking users out if device attestation fails.

## AI Tier System

Two tiers with different models and daily caps, enforced server-side:

| Tier | Model | Max Tokens | Daily Limit |
|------|-------|-----------|-------------|
| `quick` | `claude-haiku-4-5` | 512 | 300/user/day |
| `deep` | `claude-sonnet-4-6` | 1024 | 60/user/day |

Usage is tracked in `ai_usage/{uid}/{tier}/{date}` with a Firestore transaction to prevent race-condition overcounting. The client cannot override model or token limits — both are set server-side.

## Design System

The app uses a custom palette system rather than Flutter's `ThemeData.dark()`:

- [`lib/core/theme/app_palette.dart`](../../lib/core/theme/app_palette.dart) — `AppPalette` with light/dark variants
- [`lib/core/theme/app_colors.dart`](../../lib/core/theme/app_colors.dart) — `const` mirror of `AppPalette.light` for default params
- [`lib/core/theme/app_theme.dart`](../../lib/core/theme/app_theme.dart) — `AppTheme.light` applied to `MaterialApp`
- [`lib/core/theme/app_text_styles.dart`](../../lib/core/theme/app_text_styles.dart) — typography scale

Screens read the current palette via `ref.watch(paletteProvider)` to support runtime dark/light switching.

**Known limitation:** `MaterialApp` only applies `AppTheme.light`. Stock Material widgets (`AlertDialog`, `ElevatedButton`) require per-call-site color overrides for dark mode. Full `ThemeData.dark()` wiring is planned for v1.1.

## Security Architecture

1. **No API keys in client binary** — Anthropic key in Firebase Secret Manager; Supabase anon key is intentionally public (row-level security enforced server-side)
2. **Firestore rules** — every collection is ownership-scoped; `user_growth` is admin-write-only for sensitive fields
3. **Firebase App Check** — Play Integrity (Android) / App Attest (iOS) on all sensitive endpoints
4. **Server-side usage caps** — AI usage enforced in Cloud Function transaction, not client
5. **Crashlytics** — enabled in release only; `setCrashlyticsCollectionEnabled(!kDebugMode)`

See [`firestore.rules`](../../firestore.rules) and [`docs/en/SECURITY.md`](SECURITY.md).

## Directory Structure

```
ilnd_app/
├── lib/
│   ├── main.dart                    # App entry, Firebase/Supabase init, Crashlytics
│   ├── core/
│   │   ├── billing/                 # RevenueCat wrapper, isPremiumProvider
│   │   ├── ilnd/                    # AI service, memory, learner, copy helpers
│   │   ├── repositories/            # Firestore CRUD (journal, habits, referral, …)
│   │   ├── router/                  # go_router config + auth redirect
│   │   ├── services/                # AppConfig, AppCheckHeaders
│   │   ├── shell/                   # Bottom nav shell widget
│   │   ├── theme/                   # AppPalette, AppColors, AppTheme, AppTextStyles
│   │   ├── utils/                   # Validators, date helpers
│   │   └── widgets/                 # Pressable, AnimatedBackground, SkeletonCard
│   ├── features/
│   │   ├── auth/                    # Login, register, AuthNotifier
│   │   ├── chat/                    # ILND chat screen
│   │   ├── ekle/                    # Add-entry bottom sheets (journal, food, habit, mood)
│   │   ├── explore/                 # Article list + detail
│   │   ├── habits/                  # Habit list, toggle, stats
│   │   ├── home/                    # Home screen, mood check-in, daily intention
│   │   ├── journal/                 # Journal entry list
│   │   ├── legal/                   # Privacy Policy, Terms of Service screens
│   │   ├── onboarding/              # Welcome, quick-setup, first-entry
│   │   ├── premium/                 # Paywall screen
│   │   ├── profile/                 # Profile stats, settings, delete account
│   │   ├── referral/                # Referral code UI
│   │   ├── social_proof/            # Active-users badge
│   │   ├── splash/                  # Splash screen
│   │   ├── takip/                   # Tracking: macros, meals, activity, habits
│   │   └── vibe_card/               # Weekly wellness card (9:16, PNG share)
│   └── l10n/                        # app_tr.arb (template), app_en.arb
├── functions/                       # Firebase Cloud Functions (Node 20)
│   ├── index.js                     # All 4 functions
│   ├── scripts/seedArticles.js      # Admin SDK article upsert
│   └── test/                        # Jest test suite
├── content/
│   └── articles.json                # Canonical article content
├── firestore.rules                  # Firestore security rules
├── firestore.indexes.json           # Composite indexes
├── firebase.json                    # Firebase project config + emulator ports
└── .github/workflows/               # CI (ci.yml) + release (release.yml)
```

## Related Documents

- [INSTALLATION.md](INSTALLATION.md) — local dev setup
- [DEVELOPMENT.md](DEVELOPMENT.md) — daily workflow
- [FIREBASE.md](FIREBASE.md) — Firestore schema reference
- [SECURITY.md](SECURITY.md) — threat model and mitigations
- [API.md](API.md) — Cloud Functions API reference
