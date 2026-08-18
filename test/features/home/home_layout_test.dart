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

/// Web şikayeti: mood kartı hero'nun üzerine bindirildiği için
/// (Transform.translate) selamlama metniyle çakışıyordu. Kart artık
/// hero'nun altında yaşar — bu test selamlamayla mood kartının dikeyde
/// AYRIK kalmasını kilitler.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('mood kartı selamlamanın altında, çakışma yok', (tester) async {
    SharedPreferences.setMockInitialValues({});
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
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(),
        ),
      ),
    );
    // Entrance animasyonları otursun.
    await tester.pump(const Duration(milliseconds: 900));

    final l10n = lookupAppLocalizations(const Locale('tr'));
    final moodFinder = find.text(l10n.homeMoodQuestion);
    expect(moodFinder, findsOneWidget);

    // Hero 330px (handoff §1); mood satırı hero'nun altında + nefes payıyla
    // başlamalı.
    // Not: eski bindirme Transform.translate'ti (paint-only) — getRect'e
    // yansımaz; bu eşik layout'taki gerçek boşluğu kilitler (eski düzen
    // 287.5 veriyordu, ayrık düzen ~304).
    final moodRect = tester.getRect(moodFinder);
    expect(
      moodRect.top,
      greaterThanOrEqualTo(330 + 16),
      reason: 'Mood satırı hero/selamlamayla çakışmamalı, ayrık durmalı',
    );
  });
}
