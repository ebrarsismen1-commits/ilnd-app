# App Store Submission Checklist

## Google Play

### Account & Setup
- [ ] Google Play Developer account active ($25 one-time fee)
- [ ] App created in Play Console with package name `com.ilnd.ilnd_app`
- [ ] App content rating questionnaire completed (IARC)
- [ ] App category set: Health & Fitness

### Build
- [ ] Signed release AAB produced by GitHub Actions release workflow
- [ ] Version code incremented from last submission
- [ ] `minSdkVersion 26` (Android 8.0) confirmed in `android/app/build.gradle.kts`
- [ ] App size reviewed (target < 100 MB for base APK)

### Store Listing (required before production release)
- [ ] App title: "ilnd – iyi hisset, iyi yaşa" (50 char limit)
- [ ] Short description (80 chars) — Turkish and English
- [ ] Full description (4000 chars) — Turkish and English
- [ ] App icon: 512×512 PNG, no transparency
- [ ] Feature graphic: 1024×500 PNG or JPG
- [ ] Screenshots: minimum 2, maximum 8, per device type:
  - [ ] Phone (1080×1920 or similar)
  - [ ] 7-inch tablet (optional)
  - [ ] 10-inch tablet (optional)

### Data Safety (Google Play's privacy section)
- [ ] Data collection declared: email address (required), app activity
- [ ] Data sharing with third parties declared: Firebase, Supabase, Anthropic, RevenueCat
- [ ] Data encryption in transit: Yes
- [ ] Users can request deletion: Yes (in-app account deletion + email)

### Policy Compliance
- [ ] Privacy Policy URL added to store listing
- [ ] Privacy Policy URL accessible without login
- [ ] No misleading health claims in description or screenshots
- [ ] App does not collect data from users under 13 (confirm COPPA compliance)

### Pre-launch
- [ ] Internal testing track: team devices validated
- [ ] Closed testing: beta group invited and validated
- [ ] Pre-launch report reviewed in Play Console (automated device tests)
- [ ] Android Vitals baseline established

---

## Apple App Store

### Account & Setup
- [ ] Apple Developer Program enrolled ($99/year)
- [ ] App created in App Store Connect with Bundle ID `com.ilnd.ilndApp`
- [ ] App category: Health & Fitness (primary), Lifestyle (secondary)

### Build
- [ ] IPA archived from Xcode with Distribution certificate
- [ ] Version and build number match `pubspec.yaml`
- [ ] Minimum iOS version: 16.0
- [ ] No private API usage (App Store review checks automatically)

### Store Listing
- [ ] App name: "ilnd" (30 char limit)
- [ ] Subtitle: "iyi hisset, iyi yaşa" (30 chars)
- [ ] Description (4000 chars) — Turkish and English
- [ ] Promotional text (170 chars, can be changed without new build)
- [ ] Keywords (100 chars) — wellness, günlük, journal, ai, sağlık
- [ ] App icon: 1024×1024 PNG (no transparency, no rounded corners — Apple applies them)
- [ ] Screenshots per device size:
  - [ ] 6.7" iPhone (iPhone 15 Pro Max) — required
  - [ ] 6.5" iPhone (iPhone 14 Plus) — required
  - [ ] 5.5" iPhone (iPhone 8 Plus) — required
  - [ ] 12.9" iPad Pro — required if iPad supported
  - [ ] Preview videos (optional, up to 30 seconds)
- [ ] Support URL: active URL that loads without login
- [ ] Privacy Policy URL: active URL that loads without login

### App Privacy (required)
- [ ] Data collected declared per category:
  - [ ] Contact info: email address
  - [ ] User content: journal entries, photos (food)
  - [ ] Usage data: app activity (Firebase Analytics)
  - [ ] Diagnostics: crash data (Crashlytics)
- [ ] Data linked to identity: email address linked to user account
- [ ] Data used for third-party advertising: No
- [ ] ATT prompt decision: journal and AI conversation data is first-party only; confirm no cross-app tracking before skipping ATT

### Guideline Compliance
- [ ] 4.2 — App has sufficient unique functionality
- [ ] 5.1.1 — Privacy Policy present and accurate
- [ ] 5.1.1(v) — Account deletion available in-app ✓ (deleteAccount implemented)
- [ ] 3.1.1 — In-app purchases use Apple IAP ✓ (RevenueCat + Apple IAP)
- [ ] 2.1 — No crashes on review device (validated via TestFlight)
- [ ] 1.4.1 — No excessively objectionable content
- [ ] Health data: does not access HealthKit (confirm before submission)

### TestFlight Validation
- [ ] Internal testers: all screens navigated without crash
- [ ] Onboarding complete end-to-end
- [ ] AI chat works (App Check + anthropicProxy end-to-end)
- [ ] Referral flow works
- [ ] In-app purchase completes (sandbox)
- [ ] Account deletion works end-to-end
- [ ] Privacy Policy and Terms of Service accessible pre-login
- [ ] Dark mode toggle works throughout app
- [ ] Offline mode: journal entries load from cache

### Submission
- [ ] Age rating: 4+ (no objectionable content, medical disclaimer if needed)
- [ ] Export compliance: uses standard encryption (HTTPS/TLS) — submit CCATS exemption or "Yes, this app uses encryption" + confirm standard algorithms only
- [ ] Release type: Manual release (release after approval rather than immediate)

---

## Both Stores — Required Assets Not Yet Created

The following assets **do not exist in the codebase** and must be created before submission:

| Asset | Status | Notes |
|-------|--------|-------|
| App icon (1024×1024) | ❌ Not created | Must match `#8B5CF6` brand accent |
| Feature graphic (Google Play 1024×500) | ❌ Not created | |
| Phone screenshots (5-8 per store) | ❌ Not created | Show core flows: journal, chat, vibe card |
| Tablet screenshots | ❌ Not created | Required for iPad / Google Play tablet |
| App preview video | ❌ Optional | 15-30 seconds, muted |
| Short store description (80/170 chars) | ❌ Not written | |
| Full store description | ❌ Not written | Highlight AI, privacy, Gen-Z voice |
| Release notes for v1.0 | ❌ Not written | |

---

## Related Documents

- [DEPLOYMENT.md](DEPLOYMENT.md) — smoke test and rollout
- [RELEASE.md](RELEASE.md) — release process
- [SECURITY.md](SECURITY.md) — privacy and data handling
