import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/repositories/food_repository.dart';
import 'package:ilnd_app/features/habits/habit_model.dart';
import 'package:ilnd_app/features/habits/habits_provider.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/takip/takip_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Takip ekranında yer tutucu veri YOK: aktivite kartları gerçek
/// kaynaklardan (alışkanlık tamamlama + su) beslenir.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  final l10n = lookupAppLocalizations(const Locale('tr'));

  final habits = [
    Habit(
      id: 'h1',
      userId: 'u1',
      name: 'su iç',
      targetDaysPerWeek: 7,
      createdAt: DateTime(2026),
    ),
    Habit(
      id: 'h2',
      userId: 'u1',
      name: 'yürüyüş',
      targetDaysPerWeek: 5,
      createdAt: DateTime(2026),
    ),
  ];

  Future<void> pumpTakip(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          habitsProvider.overrideWith((ref) => Stream.value(habits)),
          todayCompletionsProvider.overrideWith((ref) => Stream.value({'h1'})),
          rangeCompletionsProvider.overrideWith(
            (ref, range) => Stream.value(const {}),
          ),
          todayFoodEntriesProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          toggleHabitCompletionProvider.overrideWithValue((_) async {}),
        ],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: TakipSections())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
  }

  testWidgets('yer tutucu adım kartı yok; alışkanlık sayacı gerçek', (
    tester,
  ) async {
    await pumpTakip(tester);

    // Eski sahte değer asla geri gelmesin.
    expect(find.text('4.2k'), findsNothing);

    // Gerçek metrik: 2 alışkanlıktan 1'i bugün tamam.
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text(l10n.takipHabitsDoneLabel), findsOneWidget);

    // Su kartı gerçek prefs verisi (boş gün = 0ml).
    expect(find.text(l10n.takipWaterProgress('0', '2.000')), findsOneWidget);
  });

  testWidgets('hafta/ay seçimi ızgarayı ve sayacı büyütür', (tester) async {
    await pumpTakip(tester);

    // Varsayılan pencere hafta: h1 bugün tamam, h2 değil.
    expect(find.text('1/7'), findsOneWidget);
    expect(find.text('0/7'), findsOneWidget);
    expect(find.text('0/30'), findsNothing);

    // Gün gezgini eklendikten sonra pencere seçimi 800x600 test ekranının
    // altına düşüyor: dokunmadan önce görünür alana getirilir.
    await tester.ensureVisible(find.text(l10n.takipRangeMonth));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.takipRangeMonth));
    await tester.pumpAndSettle();

    expect(find.text('1/30'), findsOneWidget);
    expect(find.text('0/30'), findsOneWidget);
    expect(find.text('1/7'), findsNothing);
  });
}
