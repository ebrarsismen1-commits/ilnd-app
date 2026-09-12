import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/repositories/food_repository.dart';
import 'package:ilnd_app/features/habits/habit_model.dart';
import 'package:ilnd_app/features/habits/habits_provider.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/takip/takip_day.dart';
import 'package:ilnd_app/features/takip/takip_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Takip ekranı bugüne çakılıydı: dün ne yediğini görmenin hiçbir yolu yoktu.
/// Gün gezgini eklendi ve ekrandaki HER bölüm artık "bugün"ün değil seçili
/// günün karşılığını göstermek zorunda. Bu testin koruduğu şey o zincir:
/// bir bölüm bugüne çakılı kalırsa kullanıcı dünün öğünlerinin yanında
/// bugünün su ve alışkanlık sayısını görür, hangi güne baktığını anlamaz.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  final l10n = lookupAppLocalizations(const Locale('tr'));

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);

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

  FoodEntry entry(String name, int kalori, DateTime at) => FoodEntry(
    id: name,
    yemekAdi: name,
    kalori: kalori,
    protein: 10,
    karbonhidrat: 20,
    yag: 5,
    createdAt: at,
  );

  late List<String> toggled;

  setUp(() => toggled = []);

  Future<void> pumpTakip(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      waterKey(dayKey(today)): 750,
      waterKey(dayKey(yesterday)): 1250,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          habitsProvider.overrideWith((ref) => Stream.value(habits)),
          // Bugün bir alışkanlık tamam, dün ikisi de.
          todayCompletionsProvider.overrideWith((ref) => Stream.value({'h1'})),
          completionsForDayProvider.overrideWith(
            (ref, day) => Stream.value(
              dayKey(day) == dayKey(yesterday) ? {'h1', 'h2'} : <String>{},
            ),
          ),
          rangeCompletionsProvider.overrideWith(
            (ref, range) => Stream.value(const {}),
          ),
          windowCompletionsProvider.overrideWith(
            (ref, window) => Stream.value(const {}),
          ),
          todayFoodEntriesProvider.overrideWith(
            (ref) => Stream.value([entry('bugün çorbası', 500, today)]),
          ),
          foodEntriesForDayProvider.overrideWith(
            (ref, day) => Stream.value(
              dayKey(day) == dayKey(yesterday)
                  ? [entry('dün mercimeği', 700, yesterday)]
                  : const [],
            ),
          ),
          toggleHabitCompletionProvider.overrideWithValue(
            (habitId) async => toggled.add(habitId),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: TakipSections())),
        ),
      ),
    );
    // Giriş animasyonu bitmeden dokunulan hedef ıskalanıyor: gezgin okları
    // Entrance'ın ölçek/kayma dönüşümünün altında hâlâ oynuyor.
    await tester.pumpAndSettle();
  }

  /// Oklarda metin yok: erişilebilirlik etiketiyle bulunurlar.
  Finder arrow(String label) => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
  );

  Future<void> tapArrow(WidgetTester tester, String label) async {
    await tester.ensureVisible(arrow(label));
    // Giriş animasyonu (Entrance) bitmeden dokunulan hedef, dönüşüm hâlâ
    // oynadığı için ıskalanıyor.
    await tester.pumpAndSettle();
    await tester.tap(arrow(label));
    await tester.pumpAndSettle();
  }

  testWidgets('gezgin geriye gidince öğün, makro, su ve alışkanlık birlikte '
      'o güne geçer', (tester) async {
    await pumpTakip(tester);

    expect(find.text(l10n.takipDayToday), findsOneWidget);
    expect(find.text('bugün çorbası'), findsOneWidget);
    expect(
      find.text(l10n.takipKcalProgress('500', '2.000')),
      findsOneWidget,
      reason: 'bugünün kalorisi',
    );
    expect(
      find.text(l10n.takipWaterProgress('750', '2.000')),
      findsOneWidget,
      reason: 'bugünün suyu',
    );
    expect(find.text('1 / 2'), findsOneWidget, reason: 'bugün 1 alışkanlık');

    await tapArrow(tester, l10n.takipDayPrev);

    expect(find.text(l10n.takipDayYesterday), findsOneWidget);
    expect(find.text('dün mercimeği'), findsOneWidget);
    expect(find.text('bugün çorbası'), findsNothing);
    expect(
      find.text(l10n.takipKcalProgress('700', '2.000')),
      findsOneWidget,
      reason: 'dünün kalorisi',
    );
    expect(
      find.text(l10n.takipWaterProgress('1.250', '2.000')),
      findsOneWidget,
      reason: 'dünün suyu',
    );
    expect(
      find.text('2 / 2'),
      findsOneWidget,
      reason: 'aktivite kartı bugüne çakılı kalmamalı',
    );
  });

  testWidgets('bugünden ileri gidilmez', (tester) async {
    await pumpTakip(tester);

    await tapArrow(tester, l10n.takipDayNext);

    expect(
      find.text(l10n.takipDayToday),
      findsOneWidget,
      reason: 'yaşanmamış günün kaydı yok, ileri ok sönük durmalı',
    );
    expect(find.text('bugün çorbası'), findsOneWidget);
  });

  testWidgets('geriye gidilen gün ileri okla ve "bugüne dön" ile geri alınır', (
    tester,
  ) async {
    await pumpTakip(tester);

    await tapArrow(tester, l10n.takipDayPrev);
    await tapArrow(tester, l10n.takipDayNext);
    expect(find.text(l10n.takipDayToday), findsOneWidget);

    await tapArrow(tester, l10n.takipDayPrev);
    await tester.ensureVisible(find.text(l10n.takipBackToToday));
    await tester.pump();
    await tester.tap(find.text(l10n.takipBackToToday));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(l10n.takipDayToday), findsOneWidget);
    expect(find.text('bugün çorbası'), findsOneWidget);
  });

  testWidgets(
    'geçmiş gün salt okunur: öğün eklenmez, alışkanlık işaretlenmez',
    (tester) async {
      await pumpTakip(tester);

      // Bugünde iki kapı da açık.
      expect(find.text(l10n.takipAddMeal), findsOneWidget);
      await tester.ensureVisible(find.text('su iç'));
      await tester.pump();
      await tester.tap(find.text('su iç'));
      await tester.pump();
      expect(toggled, ['h1']);

      await tapArrow(tester, l10n.takipDayPrev);

      expect(find.text(l10n.takipPastDayNotice), findsOneWidget);
      expect(
        find.text(l10n.takipAddMeal),
        findsNothing,
        reason: 'geçmiş güne eklenen öğün bugünün saatiyle yazılırdı',
      );

      await tester.ensureVisible(find.text('su iç'));
      await tester.pump();
      await tester.tap(find.text('su iç'));
      await tester.pump();
      expect(toggled, [
        'h1',
      ], reason: 'dünü bugünmüş gibi işaretlemek kaydı bozar');
    },
  );

  testWidgets('dar viewport 320px: gezgin satırı taşmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpTakip(tester);
    // İki ok + tarih satırı 320dp'de yan yana duruyor; taşma debug'da
    // FlutterError olarak yükselir, sessizce geçmesin.
    expect(tester.takeException(), isNull);

    await tapArrow(tester, l10n.takipDayPrev);
    expect(tester.takeException(), isNull);
    expect(find.text(l10n.takipDayYesterday), findsOneWidget);
  });

  testWidgets('boş geçmiş gün, boş bugünden farklı konuşur', (tester) async {
    await pumpTakip(tester);

    await tapArrow(tester, l10n.takipDayPrev);
    await tapArrow(tester, l10n.takipDayPrev);

    expect(find.text(l10n.takipNoMealsThatDay), findsOneWidget);
    expect(find.text(l10n.takipNoMealsYet), findsNothing);
  });
}
