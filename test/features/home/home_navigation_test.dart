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
    double width = 420,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.binding.setSurfaceSize(Size(width, 3000));
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
        GoRoute(
          path: routeFocus,
          builder: (_, _) => const Scaffold(body: Text('STUB_ODAK')),
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

  // Okuma kartı sabit 300px ama makale her gün dönüyor: 2026-08-20'de o
  // günün uzun başlığı kartı 29px taşırdı. Dar ekranlarda sarma daha erken
  // başladığı için kontrol orada yapılır.
  for (final width in const [320.0, 375.0]) {
    testWidgets('Bugün ${width.toInt()}px genişlikte taşmaz', (tester) async {
      await pumpHome(tester, width: width);
      expect(
        tester.takeException(),
        isNull,
        reason: '${width.toInt()}px genişlikte bir kart taşıyor',
      );
    });
  }

  testWidgets('takip karosuna dokununca Takip ekranı açılır', (tester) async {
    await pumpHome(tester);
    final l10n = lookupAppLocalizations(const Locale('tr'));

    await tester.tap(find.text(l10n.takipTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('STUB_TAKIP'), findsOneWidget);
  });

  testWidgets('odaklan karosuna dokununca Odaklan ekranı açılır', (
    tester,
  ) async {
    await pumpHome(tester);
    final l10n = lookupAppLocalizations(const Locale('tr'));

    await tester.tap(find.text(l10n.homeShortcutFocus));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('STUB_ODAK'), findsOneWidget);
  });

  testWidgets('ada kartındaki hap Adan ekranını açar', (tester) async {
    await pumpHome(tester);
    final l10n = lookupAppLocalizations(const Locale('tr'));

    await tester.tap(find.text(l10n.homeIslandVisit));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('STUB_ADAN'), findsOneWidget);
  });

  testWidgets('ada kartı adı olmayan kullanıcıda yüzeyin adını taşır', (
    tester,
  ) async {
    // İsim geldiğinde başlık "Ela'nın adası" olur (possessive_test); isim
    // yokken sahiplik uydurulmaz, kart yalnız yüzeyin adını söyler.
    //
    // İlerleme cümlesi ("henüz öğe yok") artık Bugün'de değil Adan
    // ekranında yaşıyor: Bugün'ün ada kartı bir özet değil, bir kapı.
    await pumpHome(tester);
    final l10n = lookupAppLocalizations(const Locale('tr'));

    expect(find.text(l10n.adanTitle), findsOneWidget);
    expect(find.text(l10n.adanEmptyProgress), findsNothing);
  });
}
