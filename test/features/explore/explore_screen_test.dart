import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/features/explore/explore_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('renders rituals rail (no dead emoji stories row) and feed', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ExploreScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    final l10n = lookupAppLocalizations(const Locale('tr'));
    expect(find.text(l10n.exploreRitualsLabel), findsOneWidget);
    // Nefes ritüeli her zaman gerçek bir hedefe (BreathScreen) açılır.
    expect(find.textContaining('nefes'), findsWidgets);
  });
}
