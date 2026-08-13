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

/// Takip ayrı bir ekran DEĞİL: Bugün'ün kendisi. Önce sekmeden, sonra
/// profilden, en son da ayrı bir rotadan çıkarıldı — her seferinde kullanıcı
/// kendi verisine ulaşamaz hâle geldi. Bu testler onu ana ekranda ve
/// ritüellerin ÜSTÜNDE tutar.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pumpHome(
    WidgetTester tester, {
    required SharedPreferences prefs,
    required DailyMacros macros,
    Set<String> habitsDone = const {},
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Alışkanlık bölümü auth'a dokunuyor (Supabase) — sahtelenir.
          toggleHabitCompletionProvider.overrideWithValue((_) async {}),
          sharedPreferencesProvider.overrideWithValue(prefs),
          profileStatsProvider.overrideWith((ref) async => ProfileStats.zero),
          weeklyCheckinCountProvider.overrideWith((ref) async => null),
          ilndMemoryProvider.overrideWith(
            (ref) => IlndMemoryNotifier(prefs, '', null),
          ),
          dailyMacrosProvider.overrideWithValue(macros),
          todayFoodEntriesProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          habitsProvider.overrideWith((ref) => Stream.value(const [])),
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
    // İki kare: ilki stream'lerin ilk değerini teslim eder, ikincisi
    // Entrance animasyonlarını oturtur. pumpAndSettle KULLANILMAZ —
    // AnimatedBackground sürekli animasyon çalıştırıyor (CLAUDE.md #12).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
  }

  testWidgets('takip bölümleri ana ekranda, ayrı ekran gerekmiyor', (
    tester,
  ) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await pumpHome(
      tester,
      prefs: prefs,
      macros: const DailyMacros(
        kalori: 1240,
        protein: 55,
        karbonhidrat: 150,
        yag: 40,
      ),
    );

    final l10n = lookupAppLocalizations(const Locale('tr'));
    // Dört takip bölümünün etiketi de ana ekranda görünür olmalı.
    expect(find.text(l10n.takipMacrosLabel), findsOneWidget);
    expect(find.text(l10n.takipMealsLabel), findsOneWidget);
    expect(find.text(l10n.takipActivityLabel), findsOneWidget);
    expect(find.text(l10n.takipHabitsLabel), findsOneWidget);
  });

  testWidgets('takip, günün okumasının ÜSTÜNDE durur', (tester) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await pumpHome(
      tester,
      prefs: prefs,
      macros: const DailyMacros(kalori: 0, protein: 0, karbonhidrat: 0, yag: 0),
    );

    final l10n = lookupAppLocalizations(const Locale('tr'));
    final takip = find.text(l10n.takipMacrosLabel);
    final okuma = find.text(l10n.homeTodaysReadTitle);
    expect(takip, findsOneWidget);
    expect(okuma, findsOneWidget);

    expect(
      tester.getRect(takip).top,
      lessThan(tester.getRect(okuma).top),
      reason:
          'Kullanıcının kendi verisi, okuyacağı içerikten önce gelmeli — '
          'takip bloğu sayfanın dibine geri kaymamalı',
    );
  });
}
