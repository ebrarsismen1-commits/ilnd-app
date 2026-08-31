import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/repositories/movement_repository.dart';
import 'package:ilnd_app/features/explore/explore_screen.dart';
import 'package:ilnd_app/features/movement/movement_program.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pump(
    WidgetTester tester, {
    List<MovementProgram>? programs,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    // Keşfet artık 400px'lik kapakla açılıyor (handoff §2: ekranın tek büyük
    // anı önce gelir), raflar onun altında. Varsayılan 800x600 viewport'ta
    // raflar sliver önbelleğinin dışında kalıp hiç kurulmuyor — testin
    // ölçtüğü şey scroll konumu değil, veri varken rafın çizilmesi.
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          if (programs != null)
            publishableMovementProgramsProvider.overrideWithValue(programs),
        ],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ExploreScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('renders rituals rail (no dead emoji stories row) and feed', (
    tester,
  ) async {
    await pump(tester);

    final l10n = lookupAppLocalizations(const Locale('tr'));
    expect(find.text(l10n.exploreRitualsLabel), findsOneWidget);
    // Nefes ritüeli her zaman gerçek bir hedefe (BreathScreen) açılır.
    expect(find.textContaining('nefes'), findsWidgets);
  });

  group('hareket programları rafı (ADR-0004)', () {
    testWidgets('program yokken raf HİÇ çizilmez', (tester) async {
      await pump(tester, programs: const []);
      final l10n = lookupAppLocalizations(const Locale('tr'));

      // Boş bir raf, olmayan bir özelliğin sözünü vermek olurdu — video
      // içeriği girilene kadar Keşfet bu bölümü hiç göstermez.
      expect(find.text(l10n.movementShelfLabel), findsNothing);
    });

    testWidgets('program varken raf başlığı ve kart görünür', (tester) async {
      await pump(
        tester,
        programs: const [
          MovementProgram(
            id: 'sabah',
            title: 'sabah açılışı',
            level: MovementLevel.medium,
            sessions: [
              MovementSession(
                id: 's1',
                title: 'boyun ve omuz',
                videoUrl: 'https://v/s1.mp4',
                minutes: 6,
              ),
            ],
          ),
        ],
      );
      final l10n = lookupAppLocalizations(const Locale('tr'));

      expect(find.text(l10n.movementShelfLabel), findsOneWidget);
      expect(find.text('sabah açılışı'), findsOneWidget);
      expect(find.text(l10n.movementSessionCount(1)), findsOneWidget);
    });
  });
}
