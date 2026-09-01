import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/repositories/food_repository.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/habits/habit_model.dart';
import 'package:ilnd_app/features/habits/habits_provider.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/takip/takip_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Alışkanlık silme.
///
/// `HabitsRepository.deleteHabit` yazılmıştı ve Firestore kuralı izin
/// veriyordu, ama metot HİÇBİR YERDEN çağrılmıyordu: arka uç hazır, arayüzde
/// kapı yok. Kullanıcı eklediği alışkanlığı kaldıramıyordu.
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
  ];

  late List<String> deleted;

  /// Alışkanlık satırının kendisi. Metne basmak jesti satırın Pressable'ına
  /// taşımayabiliyor; hedef satırın kendisi olmalı.
  Finder habitRow() => find
      .ancestor(of: find.text('su iç'), matching: find.byType(Pressable))
      .first;

  Future<void> pump(WidgetTester tester) async {
    deleted = [];
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          habitsProvider.overrideWith((ref) => Stream.value(habits)),
          todayCompletionsProvider.overrideWith(
            (ref) => Stream.value(const {}),
          ),
          rangeCompletionsProvider.overrideWith(
            (ref, range) => Stream.value(const {}),
          ),
          todayFoodEntriesProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          toggleHabitCompletionProvider.overrideWithValue((_) async {}),
          deleteHabitProvider.overrideWithValue((id) async => deleted.add(id)),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: TakipSections()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2500));
  }

  testWidgets('uzun basınca onay sorulur, onaylanınca silinir', (tester) async {
    await pump(tester);
    expect(find.text('su iç'), findsOneWidget);

    // Satır varsayılan test viewport'unun altında kalıyor; jest önce
    // görünür alana getirilmeli, yoksa ekran dışı bir koordinata gider.
    await tester.ensureVisible(habitRow());
    await tester.pump();
    await tester.longPress(habitRow());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(l10n.habitDeleteTitle), findsOneWidget);
    expect(deleted, isEmpty, reason: 'onaydan önce silinmemeli');

    await tester.tap(find.text(l10n.deleteAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(deleted, ['h1']);
  });

  testWidgets('vazgeçilince silinmez', (tester) async {
    await pump(tester);

    // Satır varsayılan test viewport'unun altında kalıyor; jest önce
    // görünür alana getirilmeli, yoksa ekran dışı bir koordinata gider.
    await tester.ensureVisible(habitRow());
    await tester.pump();
    await tester.longPress(habitRow());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(l10n.cancelAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(deleted, isEmpty);
  });

  testWidgets('kısa dokunuş işaretler, silmez', (tester) async {
    // Aynı satırda iki jest var: dokunuş tamamlama, uzun basma silme.
    // Karışırlarsa kullanıcı işaretlemeye çalışırken siler.
    await pump(tester);

    await tester.ensureVisible(habitRow());
    await tester.pump();
    await tester.tap(habitRow());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(l10n.habitDeleteTitle), findsNothing);
    expect(deleted, isEmpty);
  });
}
