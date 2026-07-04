# Contributing Guide

## Branching Strategy

```
main          ← production releases only (tagged)
develop       ← integration branch
feature/*     ← new features
fix/*         ← bug fixes
chore/*       ← non-user-facing changes
docs/*        ← documentation only
```

All work branches off `develop`. Only release commits go to `main`.

---

## Commit Convention

ilnd uses [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

**Types:**

| Type | When to use |
|------|-------------|
| `feat` | New user-facing feature |
| `fix` | Bug fix |
| `refactor` | Code restructure without behavior change |
| `docs` | Documentation only |
| `test` | Test additions or fixes |
| `chore` | Build system, dependencies, CI |
| `perf` | Performance improvement |
| `style` | Formatting, no logic change |

**Examples:**
```
feat(auth): add forgot-password screen
fix(habits): wrap toggleCompletion in Firestore transaction
refactor(ui): migrate register screen to paletteProvider
docs(api): add redeemReferralCode request/response examples
chore(ci): add flutter format check to CI pipeline
```

Breaking changes: add `!` after type, e.g. `feat(api)!: ...`, and explain in the footer.

---

## Pull Request Process

1. Branch off `develop`
2. Make your changes with conventional commits
3. Run the full test suite locally:
   ```bash
   flutter analyze
   flutter test
   dart format --set-exit-if-changed lib test
   cd functions && npm test
   ```
4. Open a PR targeting `develop`
5. PR description must include:
   - What changed and why
   - How to test the change
   - Screenshots for UI changes
6. CI must be green before merge
7. At least one approving review required

---

## Code Standards

### Dart / Flutter

- Follow `flutter_lints` ruleset (enforced by CI)
- No `print()` — use `debugPrint()` in debug code
- Always use curly braces in control flow (`if`, `for`, `while`)
- Prefer `const` constructors wherever possible
- No hardcoded color values — use `AppPalette` via `paletteProvider`
- No hardcoded strings visible to users — use `AppLocalizations`
- Riverpod: `ref.watch` in build, `ref.read` in callbacks only

### JavaScript (Cloud Functions)

- ES modules style consistent with existing `functions/index.js`
- All async functions use `async/await` (no `.then()` chains)
- All HTTP endpoints validate authentication before any business logic
- Firestore mutations that involve multiple documents use `runTransaction`
- No secrets in code — use `defineSecret()` and Firebase Secret Manager

### Comments

Write comments only for non-obvious reasons — hidden constraints, workarounds, invariants. Do not comment what the code does. Do not leave TODO comments in merged code unless paired with a tracking issue.

---

## Adding a New Cloud Function

1. Define in `functions/index.js`
2. Add App Check enforcement if handling sensitive data: `{enforceAppCheck: true}`
3. Add a test file at `functions/test/<functionName>.test.js`
4. Update [`docs/en/API.md`](API.md) with request/response documentation
5. If the function needs a client-side URL, add it to `AppConfig` in `lib/core/services/app_config.dart`

---

## Adding a New Screen

1. Create `lib/features/<feature>/<feature>_screen.dart`
2. Extend `ConsumerWidget` (or `ConsumerStatefulWidget`)
3. Use `ref.watch(paletteProvider)` for all colors
4. Pass `AppLocalizations.of(context)!` to any text or validators
5. Add the route to `lib/core/router/app_router.dart`
6. If accessible pre-auth, add to the redirect bypass list
7. Add accessibility semantics to interactive elements (44px minimum touch target)
8. Write at least one widget test

---

## i18n Requirements

Every user-visible string must be in both `.arb` files:

- Template: [`lib/l10n/app_tr.arb`](../../lib/l10n/app_tr.arb)
- Translation: [`lib/l10n/app_en.arb`](../../lib/l10n/app_en.arb)

After adding strings:
```bash
flutter gen-l10n
```

Never use string literals for user-visible text in widgets.

---

## Release Process

1. All features and fixes merged to `develop`
2. Create a release branch: `release/v1.x.x`
3. Update version in `pubspec.yaml`
4. Update `CHANGELOG.md`
5. CI must be green
6. Smoke test on physical device
7. Merge to `main`
8. Tag: `git tag v1.x.x && git push origin v1.x.x`
9. GitHub Actions release workflow builds and signs the AAB
10. Upload AAB to Google Play + archive the iOS IPA

---

## Related Documents

- [DEVELOPMENT.md](DEVELOPMENT.md) — local dev workflow
- [TESTING.md](TESTING.md) — test patterns
- [ARCHITECTURE.md](ARCHITECTURE.md) — system design context
