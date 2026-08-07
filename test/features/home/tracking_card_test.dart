import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/repositories/checkin_repository.dart';
import 'package:ilnd_app/core/repositories/food_repository.dart';
import 'package:ilnd_app/features/habits/habits_provider.dart';
import 'package:ilnd_app/features/home/home_screen.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/profile/profile_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Takip ekranının Bugün'deki tek girişi (nav v2'de sekmesi yok, profilden de
/// kaldırıldı). Kart en dipte dururken kullanıcı kendi verisine hiç
/// ulaşamıyordu; bu testler iki şeyi kilitler: kartın günün okumasının
/// ÜSTÜNDE durması ve bugünün gerçek toplamlarını göstermesi.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  String waterKeyForToday() {
    final d = DateTime.now();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return 'water_${d.year}-$mm-$dd';
  }

  Future<void> pumpHome(
    WidgetTester tester, {
    required SharedPreferences prefs,
    required DailyMacros macros,
    required Set<String> habitsDone,
  }) async {
    // Tüm sliver'lar tek karede yerleşsin (sıralama iddiası için şart).
    await tester.binding.setSurfaceSize(const Size(420, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          profileStatsProvider.overrideWith((ref) async => ProfileStats.zero),
          weeklyCheckinCountProvider.overrideWith((ref) async => null),
          ilndMemoryProvider.overrideWith(
            (ref) => IlndMemoryNotifier(prefs, '', null),
          ),
          dailyMacrosProvider.overrideWithValue(macros),
          todayCompletionsProvider.overrideWith(
            (ref) => Stream.value(habitsDone),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(),
        ),
      ),
    );
    // İki kare: ilki stream'in ilk değerini teslim eder (alışkanlık sayısı
    // aksi hâlde 0 kalır), ikincisi Entrance animasyonlarını oturtur.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
  }

  testWidgets('takip kartı günün okumasının üstünde durur', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await pumpHome(
      tester,
      prefs: prefs,
      macros: const DailyMacros(kalori: 0, protein: 0, karbonhidrat: 0, yag: 0),
      habitsDone: const {},
    );

    final l10n = lookupAppLocalizations(const Locale('tr'));
    final trackingFinder = find.text(l10n.navTracking);
    final readTitleFinder = find.text(l10n.homeTodaysReadTitle);
    expect(trackingFinder, findsOneWidget);
    expect(readTitleFinder, findsOneWidget);

    expect(
      tester.getRect(trackingFinder).top,
      lessThan(tester.getRect(readTitleFinder).top),
      reason:
          'Kullanıcının kendi verisi, okuyacağı içerikten önce gelmeli — '
          'kart en dibe geri kaymamalı',
    );
  });

  // İki durum bilerek AYRI testlerde: aynı test içinde ikinci kez
  // pumpWidget çağırmak ProviderScope'u yeniden kurmaz, ilk override'larla
  // oluşmuş provider'lar ayakta kalır (alışkanlık sayısı boş sette
  // takılıydı).
  testWidgets('veri yokken tanıtıcı alt başlık kalır', (tester) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await pumpHome(
      tester,
      prefs: prefs,
      macros: const DailyMacros(kalori: 0, protein: 0, karbonhidrat: 0, yag: 0),
      habitsDone: const {},
    );

    final l10n = lookupAppLocalizations(const Locale('tr'));
    // 0'larla dolu bir özet kullanıcıyı suçlar — non-preachy.
    expect(find.text(l10n.homeTrackingCardSubtitle), findsOneWidget);
  });

  testWidgets('veri varken bugünün toplamları gösterilir', (tester) async {
    // resetStatic() şart — getInstance() tekil örneği önbelleğe alır, yeni
    // mock değerler onsuz okunmaz (su hep 0 görünürdü).
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({waterKeyForToday(): 750});
    final prefs = await SharedPreferences.getInstance();
    await pumpHome(
      tester,
      prefs: prefs,
      macros: const DailyMacros(
        kalori: 1240,
        protein: 60,
        karbonhidrat: 120,
        yag: 40,
      ),
      habitsDone: const {'a', 'b'},
    );

    final l10n = lookupAppLocalizations(const Locale('tr'));
    expect(
      find.text(l10n.homeTrackingCardSummary(1240, 750, 2)),
      findsOneWidget,
    );
    expect(find.text(l10n.homeTrackingCardSubtitle), findsNothing);
  });
}
