import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/onboarding/screens/welcome_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Welcome ekranındaki iki dilli slogan (Türkçe satırın altında soluk
/// İngilizcesi) marka dokunuşudur ve Türkçede kalmalı. İngilizcede ise iki
/// satır birebir aynı cümle olduğu için slogan iki kez yazılıyordu; ekran
/// bu satırı locale koşuluyla çiziyor. Koşul kaldırılırsa bu test kırılır.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpWelcome(WidgetTester tester, Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const WelcomeScreen(),
        ),
      ),
    );
    // AnimatedBackground sonsuz döner — pumpAndSettle asla dönmez.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('Türkçede slogan iki dilli görünür', (tester) async {
    await pumpWelcome(tester, const Locale('tr'));

    final l10n = lookupAppLocalizations(const Locale('tr'));
    expect(find.text(l10n.welcomeTagline), findsOneWidget);
    expect(find.text(l10n.welcomeTaglineEn), findsOneWidget);
  });

  testWidgets('İngilizcede slogan tek kez yazılır', (tester) async {
    await pumpWelcome(tester, const Locale('en'));

    final l10n = lookupAppLocalizations(const Locale('en'));
    // İki anahtar aynı metni taşıyor; ikisi de çizilseydi findsNWidgets(2)
    // olurdu. Tam olarak bir kez görünmeli.
    expect(l10n.welcomeTaglineEn, l10n.welcomeTagline);
    expect(find.text(l10n.welcomeTagline), findsOneWidget);
  });
}
