import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/features/ekle/ekle_sheet.dart';
import 'package:ilnd_app/features/ekle/gorev_ekle_sheet.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('alışkanlık günleri 320px genişlikte taşmaz', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showGorevEkleSheet(context),
                child: const Text('AÇ'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('AÇ'));
    await tester.pumpAndSettle();

    expect(find.byType(Wrap), findsOneWidget);
    for (var day = 1; day <= 7; day++) {
      expect(find.text('$day'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('ekle menüsündeki kapatma düğmesi ekran okuyucuya adını söyler', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final l10n = lookupAppLocalizations(const Locale('tr'));
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showEkleSheet(context),
                child: const Text('AÇ'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('AÇ'));
    await tester.pump();
    // Route geçişi bitsin; BreathRing bilerek sürekli hareket ettiği için
    // pumpAndSettle bu ekranda hiçbir zaman tamamlanmaz.
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.bySemanticsLabel(l10n.a11yClose), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
