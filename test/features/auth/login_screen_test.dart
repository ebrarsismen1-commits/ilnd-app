import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/features/auth/login_screen.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/fake_firebase_auth.dart';

void main() {
  // AuthNotifier reads FirebaseAuth in its constructor — give it a fake with
  // no session so it resolves to AuthUnauthenticated. No network call.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    useFakeFirebaseAuth();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpLoginScreen(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ...overrides,
        ],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LoginScreen(),
        ),
      ),
    );
    // LoginScreen wraps content in AnimatedBackground, which repeats its
    // gradient animation forever — pumpAndSettle() would never return.
    // A couple of fixed pumps is enough for the initial frame to settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('renders email and password fields plus a submit button', (
    tester,
  ) async {
    await pumpLoginScreen(tester);

    expect(find.byType(TextField), findsNWidgets(2));
    final l10n = lookupAppLocalizations(const Locale('tr'));
    expect(find.text(l10n.loginSubmit), findsOneWidget);
    // "kayıt ol" lives inside a Text.rich/TextSpan, not a plain Text widget.
    expect(
      find.textContaining(l10n.loginRegisterLink, findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('shows a validation error when submitting empty fields', (
    tester,
  ) async {
    await pumpLoginScreen(tester);

    final l10n = lookupAppLocalizations(const Locale('tr'));
    await tester.tap(find.text(l10n.loginSubmit));
    await tester.pump(); // let the toast/snackbar animate in

    expect(find.text(l10n.validatorEmailRequired), findsOneWidget);
  });

  testWidgets('toggles password visibility when tapping the eye icon', (
    tester,
  ) async {
    await pumpLoginScreen(tester);

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('renders fully in English under the en locale', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LoginScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.loginSubmit), findsOneWidget); // "sign in"
    expect(find.text(l10n.authContinueWithGoogle), findsOneWidget);

    // English validation error surfaces on empty submit.
    await tester.tap(find.text(l10n.loginSubmit));
    await tester.pump();
    expect(find.text(l10n.validatorEmailRequired), findsOneWidget);
  });

  testWidgets(
    'çözülemeyen şifre sıfırlama linki sessiz kalmaz, nedeni yazılır',
    (tester) async {
      // Regresyon: link takası patladığında router kullanıcıyı giriş ekranına
      // bırakıyor ama hiçbir şey söylemiyordu — kullanıcı tarafında bu
      // "şifre yenileme ekranı yerine giriş ekranı çıkıyor" olarak görünüyordu.
      // Hata ekran açılmadan ÖNCE dolmuş olsa bile gösterilmeli.
      await pumpLoginScreen(
        tester,
        overrides: [
          authLinkErrorProvider.overrideWith(
            (ref) => AuthErrorCode.resetLinkInvalid,
          ),
        ],
      );
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('tr'));
      expect(find.text(l10n.authErrorResetLinkInvalid), findsOneWidget);
    },
  );
}
