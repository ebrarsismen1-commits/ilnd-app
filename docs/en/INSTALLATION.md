# Installation Guide

## Prerequisites

| Tool | Required Version | Install |
|------|-----------------|---------|
| Flutter | 3.44.1 | [flutter.dev/install](https://flutter.dev/install) |
| Dart | 3.12.1 (bundled with Flutter) | — |
| Node.js | 20.x | [nodejs.org](https://nodejs.org) |
| Firebase CLI | Latest | `npm install -g firebase-tools` |
| Xcode | 15+ | Mac App Store (iOS builds) |
| Android Studio | Latest | For Android emulator |
| Git | Any | — |

Verify your Flutter installation:
```bash
flutter doctor -v
```

All checkmarks should be green for your target platform. iOS requires a Mac.

---

## 1. Clone the Repository

```bash
git clone <repo-url> ilnd_app
cd ilnd_app
```

---

## 2. Environment Configuration

The app reads secrets from a `.env` file at the project root. Copy the example and fill in your values:

```bash
cp .env.example .env
```

Edit `.env`:
```ini
# Supabase
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Firebase (from google-services.json / GoogleService-Info.plist)
FIREBASE_API_KEY=AIzaSy...
FIREBASE_AUTH_DOMAIN=ilnd-app-8dcbd.firebaseapp.com
FIREBASE_PROJECT_ID=ilnd-app-8dcbd
FIREBASE_STORAGE_BUCKET=ilnd-app-8dcbd.appspot.com
FIREBASE_MESSAGING_SENDER_ID=...
FIREBASE_APP_ID=1:...:android:...  # or ios:...

# RevenueCat
REVENUECAT_API_KEY=appl_...  # or goog_... for Android

# Cloud Functions bridge (set after deploying functions)
AUTH_BRIDGE_URL=https://<region>-ilnd-app-8dcbd.cloudfunctions.net/mintFirebaseToken
```

> **Note:** `ANTHROPIC_API_KEY` is a Firebase Secret — never add it to `.env`. See [DEPLOYMENT.md](DEPLOYMENT.md) for how to set Cloud Function secrets.

---

## 3. Firebase Configuration Files

Download from Firebase Console → Project Settings:

- **Android:** `google-services.json` → place at `android/app/google-services.json`
- **iOS:** `GoogleService-Info.plist` → place at `ios/Runner/GoogleService-Info.plist`

Both files are in `.gitignore` and must be obtained from a team member or Firebase Console.

---

## 4. Flutter Dependencies

```bash
flutter pub get
```

---

## 5. Cloud Functions Setup

```bash
cd functions
npm install
cd ..
```

---

## 6. Firebase Emulator Suite (for local development)

The emulator replaces all Firebase services locally. No real Firestore or Auth calls are made during local dev.

```bash
firebase login          # first time only
firebase use ilnd-app-8dcbd
firebase emulators:start
```

Emulator ports:
| Service | Port |
|---------|------|
| Firebase Auth | 9099 |
| Firestore | 8080 |
| Cloud Functions | 5001 |
| Storage | 9199 |
| Emulator UI | 4000 |

Open [http://localhost:4000](http://localhost:4000) to inspect the emulator state.

---

## 7. Seed Article Content

After starting the emulator (or against production with appropriate credentials):

```bash
cd functions
npm run seed:articles
```

This reads [`content/articles.json`](../../content/articles.json) and upserts 10 articles into Firestore. The script is idempotent — safe to run multiple times.

---

## 8. Run the App

### iOS Simulator

```bash
open -a Simulator           # start iOS Simulator
flutter run
```

### Android Emulator

Start an AVD from Android Studio, then:

```bash
flutter run
```

### Physical Device

```bash
flutter devices             # list connected devices
flutter run -d <device-id>
```

---

## 9. Verify Installation

After the app launches:

1. Register a new account — Supabase creates the user, `mintFirebaseToken` bridges to Firebase
2. Complete onboarding (welcome → quick setup → first journal entry)
3. The first entry triggers an ILND AI response via `anthropicProxy`
4. Home screen loads with mood check-in and today's article

If the AI response works end-to-end, your installation is complete.

---

## Troubleshooting

**`flutter pub get` fails with dependency conflict**
```bash
flutter clean && flutter pub get
```

**`firebase emulators:start` hangs**
Check that ports 4000, 5001, 8080, 9099, 9199 are free:
```bash
lsof -i :8080
```

**App launches but shows `_StartupFailureApp`**
Supabase URL or anon key is wrong in `.env`. Check the values match your Supabase project.

**Articles don't load**
Run `npm run seed:articles` from the `functions/` directory. If using the emulator, make sure it is running before seeding.

**`mintFirebaseToken` returns 401**
The `AUTH_BRIDGE_URL` in `.env` is missing or points to the wrong function URL. After deploying functions, update this value.

---

## Related Documents

- [DEVELOPMENT.md](DEVELOPMENT.md) — daily workflow, code generation, linting
- [DEPLOYMENT.md](DEPLOYMENT.md) — production deployment
- [FIREBASE.md](FIREBASE.md) — Firestore schema and rules
