import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/repositories/food_repository.dart';
import 'package:ilnd_app/features/habits/habits_provider.dart';
import 'package:ilnd_app/core/repositories/checkin_repository.dart';
import 'package:ilnd_app/features/home/home_screen.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/profile/profile_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gece ritüeli daveti yalnız akşam penceresinde ve bu gece henüz
/// yapılmamışken görünür.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  String today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> pumpHome(
    WidgetTester tester, {
    required int hour,
    Map<String, Object> initialPrefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(initialPrefs);
    final prefs = await SharedPreferences.getInstance();
    // Bugün ekranı Takip bloğunu da taşıdığı için uzun: varsayılan
    // 800x600 viewport'ta alt bölümler hiç yerleşmiyor.
    await tester.binding.setSurfaceSize(const Size(420, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Bugün ekranı artık Takip bölümlerini de taşıyor; alışkanlık
          // bölümü auth'a dokunuyor (Supabase), o yüzden sahtelenir.
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
          sharedPreferencesProvider.overrideWithValue(prefs),
          profileStatsProvider.overrideWith((ref) async => ProfileStats.zero),
          weeklyCheckinCountProvider.overrideWith((ref) async => null),
          ilndMemoryProvider.overrideWith(
            (ref) => IlndMemoryNotifier(prefs, '', null),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(hourOverride: hour),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
  }

  testWidgets('akşam 22:00, yapılmamış → davet görünür', (tester) async {
    await pumpHome(tester, hour: 22);
    final l10n = lookupAppLocalizations(const Locale('tr'));
    expect(find.text(l10n.sleepRitualHomeCardTitle), findsOneWidget);
  });

  testWidgets('gündüz 15:00 → davet gizli', (tester) async {
    await pumpHome(tester, hour: 15);
    final l10n = lookupAppLocalizations(const Locale('tr'));
    expect(find.text(l10n.sleepRitualHomeCardTitle), findsNothing);
  });

  testWidgets('akşam 22:00 ama bu gece yapılmış → davet gizli', (tester) async {
    await pumpHome(
      tester,
      hour: 22,
      initialPrefs: {'sleep_ritual_date': today(), 'sleep_ritual_done': true},
    );
    final l10n = lookupAppLocalizations(const Locale('tr'));
    expect(find.text(l10n.sleepRitualHomeCardTitle), findsNothing);
  });
}
