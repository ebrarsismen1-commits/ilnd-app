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

/// Takip kendi ekranı (tasarım handoff §6, owner kararı 2026-08-19). Bir süre
/// Bugün'ün içine gömülüydü; geri çıkarıldı. Bu geçmişte iki kez kaybolmuş bir
/// yüzey (önce sekmeden, sonra profilden), o yüzden testin işi Bugün'de ona
/// giden BİR KAPI daima bulunmasını garanti etmek: Takip'in ana ekranda
/// gömülü olmaması, ulaşılamaz olması demek değildir.
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

  testWidgets('takip bölümleri ana ekrana gömülü DEĞİL', (tester) async {
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
    // Takip bölümlerinin hiçbiri Bugün'de çizilmez — onlar artık Takip
    // ekranında yaşıyor.
    expect(find.text(l10n.takipMacrosLabel), findsNothing);
    expect(find.text(l10n.takipMealsLabel), findsNothing);
    expect(find.text(l10n.takipActivityLabel), findsNothing);
    expect(find.text(l10n.takipHabitsLabel), findsNothing);
  });

  testWidgets('ana ekranda Takip ekranına giden karo var', (tester) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await pumpHome(
      tester,
      prefs: prefs,
      macros: const DailyMacros(kalori: 0, protein: 0, karbonhidrat: 0, yag: 0),
    );

    final l10n = lookupAppLocalizations(const Locale('tr'));
    // Ada tasarımı 03: ruh halinin altında üç kapı — günlük, odaklan, takip.
    // Takip yüzeyi bu depoda iki kez kayboldu (önce sekmeden, sonra
    // profilden); kapısı Bugün'de kalmalı.
    expect(
      find.text(l10n.takipTitle),
      findsOneWidget,
      reason: 'Takip ekranına giden kapı ana ekrandan kaybolmamalı',
    );
    expect(find.text(l10n.journalTitle), findsOneWidget);
    expect(find.text(l10n.homeShortcutFocus), findsOneWidget);

    // Günün okuması Bugün'den çıktı: Keşfet'teki "Bugün senin için" rafı
    // aynı işi kişiselleştirilmiş olarak yapıyor, iki yerde iki farklı
    // öneri kullanıcının kafasını karıştırıyordu.
    expect(find.text(l10n.homeTodaysReadTitle), findsNothing);
  });
}
