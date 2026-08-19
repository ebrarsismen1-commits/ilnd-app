import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/repositories/checkin_repository.dart';
import 'package:ilnd_app/core/repositories/food_repository.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/features/adan/adan_model.dart';
import 'package:ilnd_app/features/adan/adan_repository.dart';
import 'package:ilnd_app/features/habits/habits_provider.dart';
import 'package:ilnd_app/features/home/home_screen.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/profile/profile_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bugün'den çıkan kapılar GERÇEKTEN açılıyor mu?
///
/// Bir satırın ekranda bulunması, dokunulduğunda bir yere gittiği anlamına
/// gelmiyor — Takip yüzeyi bu depoda tam olarak böyle iki kez kayboldu
/// (önce sekmeden, sonra profilden). Bu testler dokunuşu sürer ve hedefin
/// açıldığını doğrular.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pumpHome(
    WidgetTester tester, {
    IslandState island = const IslandState(),
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.binding.setSurfaceSize(const Size(420, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: routeHome,
      routes: [
        GoRoute(path: routeHome, builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: routeTakip,
          builder: (_, _) => const Scaffold(body: Text('STUB_TAKIP')),
        ),
        GoRoute(
          path: routeAdan,
          builder: (_, _) => const Scaffold(body: Text('STUB_ADAN')),
        ),
        GoRoute(
          path: routeStreakCard,
          builder: (_, _) => const Scaffold(body: Text('STUB_STREAK')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          profileStatsProvider.overrideWith((ref) async => ProfileStats.zero),
          weeklyCheckinCountProvider.overrideWith((ref) async => null),
          ilndMemoryProvider.overrideWith(
            (ref) => IlndMemoryNotifier(prefs, '', null),
          ),
          dailyMacrosProvider.overrideWithValue(
            const DailyMacros(kalori: 0, protein: 0, karbonhidrat: 0, yag: 0),
          ),
          todayFoodEntriesProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          habitsProvider.overrideWith((ref) => Stream.value(const [])),
          todayCompletionsProvider.overrideWith(
            (ref) => Stream.value(const <String>{}),
          ),
          toggleHabitCompletionProvider.overrideWithValue((_) async {}),
          islandStateProvider.overrideWith((ref) => Stream.value(island)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
  }

  testWidgets('takip satırına dokununca Takip ekranı açılır', (tester) async {
    await pumpHome(tester);
    final l10n = lookupAppLocalizations(const Locale('tr'));

    await tester.tap(find.text(l10n.homeTrackRowSubtitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('STUB_TAKIP'), findsOneWidget);
  });

  testWidgets('ADAN bloğuna dokununca Adan ekranı açılır', (tester) async {
    await pumpHome(tester);
    final l10n = lookupAppLocalizations(const Locale('tr'));

    await tester.tap(find.text(l10n.adanLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('STUB_ADAN'), findsOneWidget);
  });

  testWidgets('haftalık kart satırı streak kartını açar', (tester) async {
    await pumpHome(tester);
    final l10n = lookupAppLocalizations(const Locale('tr'));

    await tester.tap(find.text(l10n.homeWeeklyCardRowTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('STUB_STREAK'), findsOneWidget);
  });

  testWidgets('ada boşken ilerleme satırı "henüz öğe yok" der', (tester) async {
    await pumpHome(tester);
    final l10n = lookupAppLocalizations(const Locale('tr'));

    // Sayı uydurmuyoruz: kazanılmış öğe yokken "0 öğe" demek yerine
    // durumu söyleyen bir cümle çıkar.
    expect(find.text(l10n.adanEmptyProgress), findsOneWidget);
  });

  testWidgets('kazanılmış öğe varsa ilerleme satırı sıradakini söyler', (
    tester,
  ) async {
    await pumpHome(tester, island: const IslandState(earned: {'lantern'}));
    final l10n = lookupAppLocalizations(const Locale('tr'));

    expect(
      find.text(l10n.adanProgress(1, l10n.adanItemPine)),
      findsOneWidget,
      reason: 'Bir öğe kazanılmışsa sıradaki öğe çam olmalı',
    );
  });
}
