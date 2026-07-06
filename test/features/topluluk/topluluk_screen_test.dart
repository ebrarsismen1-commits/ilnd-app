import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/widgets/breath_ring.dart';
import 'package:ilnd_app/features/topluluk/topluluk_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pump(WidgetTester tester, Locale locale) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TopulukScreen(),
        ),
      ),
    );
    // AnimatedBackground + BreathRing sonsuz animasyon → pumpAndSettle yasak.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('renders community v1 with breath ring and invite CTA (tr)', (
    tester,
  ) async {
    await pump(tester, const Locale('tr'));
    final l10n = lookupAppLocalizations(const Locale('tr'));
    expect(find.text(l10n.topulukTitle), findsOneWidget);
    expect(find.text(l10n.topulukComingTitle), findsOneWidget);
    expect(find.text(l10n.topulukInviteCta), findsOneWidget);
    expect(find.byType(BreathRing), findsOneWidget);
  });

  testWidgets('renders fully in English under the en locale', (tester) async {
    await pump(tester, const Locale('en'));
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.topulukTitle), findsOneWidget); // "community."
    expect(find.text(l10n.topulukInviteCta), findsOneWidget);
  });
}
