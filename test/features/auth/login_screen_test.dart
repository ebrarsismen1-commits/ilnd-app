import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/features/auth/login_screen.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  // AuthNotifier reads Supabase.instance.client in its constructor — give
  // it a real (but fake-credentialed) client so it resolves to
  // AuthUnauthenticated instead of throwing "Supabase not initialized".
  // No network call happens here: currentSession just reads local state.
  setUpAll(() async {
    // Supabase.initialize() uses SharedPreferences internally for session
    // storage, so the mock must be in place before it runs.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpLoginScreen(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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
}
