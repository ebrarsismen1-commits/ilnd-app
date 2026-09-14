import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/repositories/checkin_repository.dart';
import 'package:ilnd_app/core/repositories/food_repository.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/features/adan/adan_model.dart';
import 'package:ilnd_app/features/adan/island_name_provider.dart';
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
    String? islandName,
    double width = 420,
    double height = 3000,
    double textScale = 1,
    Locale locale = const Locale('tr'),
    int hour = 10,
    Map<String, Object> initialPrefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(initialPrefs);
    final prefs = await SharedPreferences.getInstance();

    await tester.binding.setSurfaceSize(Size(width, height));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: routeHome,
      routes: [
        GoRoute(
          path: routeHome,
          builder: (_, _) => HomeScreen(hourOverride: hour),
        ),
        GoRoute(
          path: routeChat,
          builder: (_, _) => const Scaffold(body: Text('STUB_CHAT')),
        ),
        GoRoute(
          path: routeSleepRitual,
          builder: (_, _) => const Scaffold(body: Text('STUB_NIGHT')),
        ),
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
          islandNameProvider.overrideWithValue(AsyncData(islandName)),
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
          locale: locale,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets(
    'mood gives immediate feedback without leaving Home, then CTA opens night routine',
    (tester) async {
      await pumpHome(tester, hour: 22);
      final l = lookupAppLocalizations(const Locale('tr'));
      await tester.tap(find.text(l.homeMoodTired));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text(l.homeFeedbackTired), findsOneWidget);
      expect(find.text(l.homeNextNightCta), findsOneWidget);
      expect(find.byKey(const ValueKey('home-primary-action')), findsOneWidget);
      await tester.tap(find.text(l.homeNextNightCta));
      await tester.pumpAndSettle();
      expect(find.text('STUB_NIGHT'), findsOneWidget);
    },
  );

  testWidgets('a week away offers a short check-in and opens chat', (
    tester,
  ) async {
    await pumpHome(
      tester,
      initialPrefs: {
        'home_last_visit': DateTime.now()
            .subtract(const Duration(days: 8))
            .toIso8601String(),
      },
    );
    final l = lookupAppLocalizations(const Locale('tr'));
    expect(find.text(l.homeNextRestartTitle), findsOneWidget);
    await tester.tap(find.text(l.homeNextRestartCta));
    await tester.pumpAndSettle();
    expect(find.text('STUB_CHAT'), findsOneWidget);
  });

  for (final locale in const [Locale('tr'), Locale('en')]) {
    testWidgets('large text at 320px remains usable in $locale', (
      tester,
    ) async {
      await pumpHome(tester, width: 320, textScale: 2, locale: locale);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('home-primary-action')), findsOneWidget);
    });
  }

  if (Platform.environment['ILND_HOME_PREVIEW'] case final String path) {
    testWidgets('export real-font home preview', (tester) async {
      await tester.runAsync(() async {
        for (final (family, asset) in [
          ('Lora', 'assets/fonts/Lora-Regular.ttf'),
          ('DMSans', 'assets/fonts/DMSans-Regular.ttf'),
          ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
        ]) {
          await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
        }
      });
      await pumpHome(tester, width: 390, height: 1100, hour: 10);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find
            .ancestor(
              of: find.byType(HomeScreen),
              matching: find.byType(RepaintBoundary),
            )
            .first,
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File(path).writeAsBytes(data.buffer.asUint8List());
        image.dispose();
      });
    });
  }

  testWidgets('home preview reflects only server-earned objects', (
    tester,
  ) async {
    await pumpHome(
      tester,
      island: const IslandState(earned: {'pine', 'lantern'}),
    );
    expect(find.byKey(const ValueKey('island-earned-pine')), findsOneWidget);
    expect(find.byKey(const ValueKey('island-earned-lantern')), findsOneWidget);
    expect(find.byKey(const ValueKey('island-earned-oven')), findsNothing);
    final l = lookupAppLocalizations(const Locale('tr'));
    expect(
      tester.getRect(find.text(l.homeIslandVisit)).bottom,
      lessThan(
        tester.getRect(find.byKey(const ValueKey('home-primary-action'))).top,
      ),
    );
  });

  testWidgets('custom island name appears on the home card', (tester) async {
    await pumpHome(tester, islandName: 'Sakin Koy');
    expect(find.text('Sakin Koy'), findsOneWidget);
  });

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
