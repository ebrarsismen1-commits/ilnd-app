# ILND security hardening — manual console checklist

Branch: `security/ilnd-hardening` · Audit date: 2026-09-13

These settings cannot be verified or changed from the repository. Nothing in this
branch touched production. Work top to bottom: **staging first, then production**.
Tick each item only after checking it in the console, not after reading the code.

---

## 0. Deploy order (the new code depends on it)

The client and server changed together. Deploying out of order breaks features
for real users.

| # | Step | Why the order matters |
|---|------|-----------------------|
| 0.1 | Create a staging Firebase project and a staging Supabase project; add a `staging` alias to `.firebaserc` | There is no staging today; every step below should run there first (audit C-2) |
| 0.2 | Apply `supabase/migrations/20260913000000_profiles_rls.sql` to staging, run `supabase test db` locally, then apply to production | Profiles are protected only by RLS (H-8) |
| 0.3 | `firebase deploy --only firestore:indexes --project <alias>` and wait until the `daily_checkins (userId asc, date desc)` index is **Enabled** | `syncIslandItems` fails its query until the index is built (Phase 7) |
| 0.4 | `firebase deploy --only functions --project <alias>` | The new app calls `ensureReferralCode` and reads `events.rsvpCount` / `public_stats`; these must exist before the client ships |
| 0.5 | `npm run backfill:counters -- --project=<id> [--confirm-prod]` | Otherwise existing events show 0 attendees and the social-proof badge is hidden until the hourly job runs |
| 0.6 | `firebase deploy --only firestore:rules,storage --project <alias>` | Old clients read `daily_checkins`/`rsvps` directly; once rules deploy those reads fail. Ship the client update (0.7) in the same window and keep the old version's degraded behaviour in mind |
| 0.7 | Release the app build from this branch | |

---

## 1. Firebase

### App Check (audit H-5)
- [ ] App Check → Apps: Android (Play Integrity) and iOS (App Attest, production environment) registered
- [ ] Web: create a reCAPTCHA Enterprise key, add `RECAPTCHA_SITE_KEY` to the web build `.env`
- [ ] Debug tokens: only for staging/debug builds; **none registered on production**, or listed and owned
- [ ] Functions env: keep `APP_CHECK_MODE=monitor` after deploy
- [ ] Cloud Logging: create a log-based metric on `jsonPayload.event="app_check"` grouped by `status`
- [ ] When `missing` + `invalid` stay below ~1% of calls for a full week: set `APP_CHECK_MODE=enforce` and redeploy functions
- [ ] Firestore App Check enforcement: enable in the console only after the same metric is healthy
- [ ] Remember: App Check is **not** authorization. Rules and function auth checks stay the real boundary

### Authentication
- [ ] Authentication → Sign-in method: **Anonymous disabled**, **Email/Password disabled**, no other native provider enabled. All sessions must come from `mintFirebaseToken` (backend rejects others since Phase 3, but disable them anyway)
- [ ] Authorized domains: only the Hosting domains you actually use

### Firestore
- [ ] Rules deployed from this branch (compare the console's rules text with `firestore.rules` at the deployed commit)
- [ ] Rules Playground spot checks: user A reading `daily_checkins`, `events/{id}/rsvps`, another user's `habits` → denied
- [ ] Database location noted; confirm it is compatible with the `onRsvpWritten` trigger region
- [ ] Point-in-time recovery enabled; scheduled daily exports configured (disaster scenario D)
- [ ] `config/ai` document exists (optional fields `enabled`, `dailyUsdLimit`); know how to set `enabled: false` in an incident

### Storage (audit H-8)
- [ ] Rules show the deny-all `storage.rules` from this branch (no "test mode" expiry rule left)
- [ ] Bucket has no public IAM bindings (`allUsers` / `allAuthenticatedUsers`)
- [ ] Old files under `users/` reviewed (the app never uploaded any; anything there is unexpected)

### Cloud Functions configuration
- [ ] Runtime shows **nodejs22** for every function (nodejs20 is decommissioned 2026-10-30)
- [ ] Secrets in Secret Manager: `ANTHROPIC_API_KEY`, `SUPABASE_SERVICE_ROLE_KEY`
- [ ] `REVENUECAT_SECRET_KEY` set before paid subscriptions go live; move it to Secret Manager (audit M-13)
- [ ] `SUPABASE_URL` set (otherwise sign-in and account deletion fail)
- [ ] `ALLOWED_ORIGINS` set if the web app is served from a custom domain (otherwise web calls fail CORS; mobile unaffected)
- [ ] Optional: `AI_DAILY_USD_LIMIT` if the default $5/user/day is wrong for your pricing
- [ ] Scheduled jobs exist: `weeklyActiveStats` (hourly), `retryAccountDeletions` (every 6h)
- [ ] `maxInstances` reviewed against expected load for `anthropicProxy` (audit M-2, scenario J)

### Budget and alerts
- [ ] GCP Billing budget with alerts at 50 / 90 / 100 %
- [ ] Alert: Cloud Functions error rate and p95 latency per function
- [ ] Alert: log-based metrics for `ai_upstream_failed`, `account_deletion_incomplete`, `mint_rejected`, `anthropicProxy` 429 `concurrency-limit` / `daily-cost-limit`
- [ ] Alert: Cloud Audit Logs on `firebaserules.releases.update` (someone deployed rules; audit scenario F)
- [ ] Crashlytics velocity alerts enabled

---

## 2. Supabase

- [ ] **RLS enabled on every table in `public`** (Database → Tables). Any private table without RLS is launch-blocking
- [ ] `profiles` policies after the migration: exactly `profiles_select_own`, `profiles_insert_own`, `profiles_update_own`; no "viewable by everyone" policy
- [ ] `profiles.id` foreign key to `auth.users` is `ON DELETE CASCADE` (the migration adds one only if none exists)
- [ ] Table privileges: `anon` has none on `profiles`; `authenticated` has SELECT/INSERT/UPDATE only (no TRUNCATE/DELETE)
- [ ] Storage: no buckets expected. If any exist, they are private and have owner-only policies
- [ ] Edge Functions: none expected. If any exist, review their secrets and JWT verification
- [ ] RPC / Postgres functions exposed in `public`: none expected; any `SECURITY DEFINER` function reviewed
- [ ] Auth → Providers: Email "Confirm email" **on**; Anonymous sign-ins **off**
- [ ] Auth → Attack protection: CAPTCHA enabled for sign-up and password reset; rate limits reviewed (audit C-1 sybil accounts)
- [ ] Auth → URL configuration: redirect allow-list only contains the real web origins and `com.ilnd.app://login-callback`
- [ ] Decode one real access token and confirm `aud = "authenticated"` and `role = "authenticated"` (the bridge now requires both)
- [ ] Service role key: only in Firebase Secret Manager. It must never appear in `.env`. The local `.env` has a comment inviting you to paste it there (audit L-3): **delete that comment**. If the key was ever placed in `.env` or a build, rotate the JWT secret / service key

---

## 3. Anthropic

- [ ] **Rotate the API key.** An earlier version compiled the key into the client binary (git history documents it); confirm that key is revoked, not just replaced
- [ ] Workspace spend limit set (monthly hard cap)
- [ ] Usage / spend email alerts configured
- [ ] Key is used only by `anthropicProxy` (Secret Manager); no developer machine uses the production key

---

## 4. GitHub

- [ ] Settings → Actions → General: "Workflow permissions" = **Read repository contents** (workflows now declare `contents: read`, but set the default too)
- [ ] "Allow GitHub Actions to create and approve pull requests" off
- [ ] Branch protection on `main`: required reviews, required status checks (CI), no force pushes
- [ ] Tag protection / rulesets for `v*.*.*` (release builds run on tags)
- [ ] Repository secrets inventory: `GOOGLE_SERVICES_JSON_BASE64`, `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `ANDROID_STORE_PASSWORD`, `FIREBASE_APP_CHECK_TEST_APP_ID`; remove anything unused
- [ ] Secret scanning and push protection enabled
- [ ] Dependabot alerts and security updates enabled (`.github/dependabot.yml` added)
- [ ] Production deploys: an environment with required reviewers, deploying via Workload Identity Federation (no JSON keys)

---

## 5. Open product / engineering decisions (not fixed in code)

| Audit item | What is needed |
|---|---|
| M-4 premium content | Paid plan/program content is still readable by any signed-in user; move paid days to a server-gated subcollection keyed on a server entitlement document |
| M-7 unbounded listeners | Paginate the journal list; cache article/plan catalogues |
| M-9 minimum app version | Send an app build header, reject old builds with 426, show an update screen (needs `package_info_plus`) |
| M-10 consent | Explicit consent screen for AI processing of health/journal data and for analytics; store consent version and timestamp |
| M-13 subscriptions | RevenueCat webhook → `entitlements/{uid}`; last-known-good fallback during RevenueCat outages |
| M-5 iOS / session storage | Exclude app data from iCloud backup on iOS; store the Supabase session in secure storage (needs `flutter_secure_storage`) |
| M-11 full CSP | Add a script-src CSP after testing the web app on staging in a browser |
| Flutter packages | Major upgrades (Firebase, Riverpod, go_router, purchases_flutter…) in a separate branch, coordinated with in-progress `pubspec` work |
| Overlapping branches | `fix/ai-kota-tavani-ve-calisma-zamani`, `fix/gizlilik-ve-kural-testleri`, `fix/rsvp-kontenjan-sunucuda` (2026-09-09, unmerged) fix some of the same findings differently; decide which to keep before merging |
