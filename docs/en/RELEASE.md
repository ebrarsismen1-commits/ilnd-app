# Release Guide

## Versioning

ilnd follows [Semantic Versioning](https://semver.org/):

- `MAJOR.MINOR.PATCH+BUILD`
- **MAJOR:** Breaking changes to user data or authentication flow
- **MINOR:** New features (backward compatible)
- **PATCH:** Bug fixes
- **BUILD:** Monotonically increasing integer for store submissions (e.g., `1.0.0+1`)

Current version: `1.0.0+1` (in `pubspec.yaml`)

---

## Release Types

| Type | Tag Format | Example |
|------|-----------|---------|
| Release Candidate | `v{version}-rc{n}` | `v1.0.0-rc1` |
| Production | `v{version}` | `v1.0.0` |
| Hotfix | `v{version}` (patch bump) | `v1.0.1` |

---

## Release Checklist

### 1. Code Freeze

```bash
git checkout develop
git pull origin develop
git checkout -b release/v1.x.x
```

### 2. Version Bump

Edit `pubspec.yaml`:
```yaml
version: 1.x.x+{build_number}
```

Build number must be higher than the last submitted build. Track it in a release log.

### 3. Changelog

Update `CHANGELOG.md`:
- Move unreleased items under the new version heading
- Add date
- Review Known Limitations section

### 4. Final Checks

```bash
flutter analyze
flutter test
dart format --set-exit-if-changed lib test
cd functions && npm test
```

All must pass.

### 5. Smoke Test

Install a release build on a physical device. Complete the smoke test checklist in [DEPLOYMENT.md](DEPLOYMENT.md).

### 6. Commit and Tag

```bash
git add pubspec.yaml CHANGELOG.md
git commit -m "chore(release): bump version to v1.x.x"
git tag v1.x.x
git push origin release/v1.x.x
git push origin v1.x.x
```

Pushing the tag triggers the GitHub Actions release workflow.

### 7. Merge

```bash
git checkout main && git merge release/v1.x.x
git checkout develop && git merge release/v1.x.x
git branch -d release/v1.x.x
```

---

## GitHub Actions Release Workflow

Defined in [`.github/workflows/release.yml`](../../.github/workflows/release.yml).

Triggered by: tags matching `v*.*.*`

Steps:
1. Check that all signing secrets are configured
2. Decode `ANDROID_KEYSTORE_BASE64` secret to a `.jks` file
3. Build signed release AAB: `flutter build appbundle --release`
4. Delete the keystore file from the runner
5. Upload signed AAB as a GitHub Actions artifact

Download the artifact from the Actions run and upload it to Google Play Console → Internal Testing → promote to production when ready.

---

## Android Release

### Signing

The release workflow signs the AAB automatically. Locally, you can sign a debug build with:
```bash
flutter build apk --debug       # debug signing
flutter build appbundle         # release (requires key.properties)
```

For local release builds, `android/key.properties` must exist. See [`android/KEYSTORE.md`](../../android/KEYSTORE.md).

### Play Store Tracks

| Track | Purpose |
|-------|---------|
| Internal Testing | Team validation |
| Closed Testing | Beta users |
| Open Testing | Opt-in public beta |
| Production | Full rollout (start at 10%, then 50%, then 100%) |

Rollout percentage can be halted in Play Console at any time.

---

## iOS Release

### Building

```bash
# In Xcode: Product → Archive
# Or via Fastlane (not yet configured)
```

Archive → Xcode Organizer → Distribute App → App Store Connect → Upload

### TestFlight

After upload:
1. TestFlight build processing takes 15-30 minutes
2. Add build to TestFlight internal testing group
3. Share via TestFlight link with external testers

### App Store Submission

1. Go to App Store Connect → Versions → New Version
2. Fill in release notes (must be in all submitted locales)
3. Add screenshots for each device size (required)
4. Submit for review
5. Typical review time: 24-48 hours

---

## Post-Release Steps

1. **Monitor Crashlytics** for the first 24 hours — see [DEPLOYMENT.md](DEPLOYMENT.md)
2. **Create GitHub release** from the tag with changelog excerpt
3. **Announce** to team/users if applicable
4. **Prune release branch** if not already deleted

---

## Hotfix Process

For critical production bugs:

```bash
git checkout main
git checkout -b hotfix/v1.x.y
# Make the fix
git commit -m "fix(<scope>): <description>"
git checkout main && git merge hotfix/v1.x.y
git checkout develop && git merge hotfix/v1.x.y
git tag v1.x.y
git push origin v1.x.y
git branch -d hotfix/v1.x.y
```

---

## Related Documents

- [DEPLOYMENT.md](DEPLOYMENT.md) — pre-deploy and smoke test
- [CHANGELOG.md](../../CHANGELOG.md) — full version history
- [APP_STORE_CHECKLIST.md](APP_STORE_CHECKLIST.md) — store submission checklist
