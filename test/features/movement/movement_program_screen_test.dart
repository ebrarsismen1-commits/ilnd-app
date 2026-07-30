import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/billing/entitlement.dart';
import 'package:ilnd_app/core/repositories/movement_repository.dart';
import 'package:ilnd_app/features/movement/movement_program.dart';
import 'package:ilnd_app/features/movement/movement_program_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  const program = MovementProgram(
    id: 'sabah',
    title: 'sabah açılışı',
    description: 'Üç kısa seans.',
    level: MovementLevel.medium,
    sessions: [
      MovementSession(
        id: 's1',
        title: 'boyun ve omuz',
        videoUrl: 'https://v/s1.mp4',
        minutes: 6,
      ),
      MovementSession(
        id: 's2',
        title: 'sırt açılışı',
        videoUrl: 'https://v/s2.mp4',
        minutes: 4,
      ),
      // Videosu henüz yüklenmemiş seans: ekranda HİÇ görünmemeli.
      MovementSession(id: 's3', title: 'kalça esnetme', videoUrl: ''),
    ],
  );

  Future<void> pump(
    WidgetTester tester, {
    MovementProgram p = program,
    Set<String> done = const {},
    bool premiumAccess = false,
    Locale locale = const Locale('tr'),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          movementProgressProvider.overrideWith(
            (ref, id) =>
                Stream.value(MovementProgress(completedSessionIds: done)),
          ),
          hasPremiumAccessProvider.overrideWithValue(premiumAccess),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MovementProgramScreen(program: p),
        ),
      ),
    );
    // İlerleme bir stream'den gelir: ilk pump widget'ı kurar, ikincisi
    // stream'in ilk değerini işler (topluluk_screen_test'teki desen).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('yalnız oynatılabilir seansları listeler', (tester) async {
    await pump(tester);
    final l10n = lookupAppLocalizations(const Locale('tr'));

    expect(find.text('boyun ve omuz'), findsOneWidget);
    expect(find.text('sırt açılışı'), findsOneWidget);
    // Videosuz seans ne listede ne de sayıda yer alır.
    expect(find.text('kalça esnetme'), findsNothing);
    expect(find.text(l10n.movementSessionCount(2)), findsOneWidget);
    // Süre de yalnız oynatılabilir seanslardan: 6 + 4.
    expect(find.text(l10n.movementMinutes(10)), findsOneWidget);
  });

  testWidgets('hiç başlanmamış programda "Başla" gösterir', (tester) async {
    await pump(tester);
    final l10n = lookupAppLocalizations(const Locale('tr'));

    expect(find.text(l10n.movementStart), findsOneWidget);
    expect(find.text(l10n.movementProgress(0, 2)), findsOneWidget);
    expect(find.text(l10n.movementSessionDone), findsNothing);
  });

  testWidgets('yarım kalmış programda "Devam et" ve tamamlanan seans', (
    tester,
  ) async {
    await pump(tester, done: {'s1'});
    final l10n = lookupAppLocalizations(const Locale('tr'));

    expect(find.text(l10n.movementContinue), findsOneWidget);
    expect(find.text(l10n.movementProgress(1, 2)), findsOneWidget);
    expect(find.text(l10n.movementSessionDone), findsOneWidget);
  });

  testWidgets('program bitince "Yeniden izle" ve tamamlandı satırı', (
    tester,
  ) async {
    await pump(tester, done: {'s1', 's2'});
    final l10n = lookupAppLocalizations(const Locale('tr'));

    expect(find.text(l10n.movementReplay), findsOneWidget);
    expect(find.text(l10n.movementAllDone), findsOneWidget);
  });

  testWidgets('premium program kilitli görünür, erişim varsa açılır', (
    tester,
  ) async {
    const locked = MovementProgram(
      id: 'guclu',
      title: 'güçlü hafta',
      premium: true,
      sessions: [
        MovementSession(
          id: 's1',
          title: 'alt beden',
          videoUrl: 'https://v/s1.mp4',
          minutes: 12,
        ),
      ],
    );

    await pump(tester, p: locked);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);

    // Aynı program, premium erişimiyle: kilit yok.
    await pump(tester, p: locked, premiumAccess: true);
    expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('EN dilinde çeviri uygulanır, eksik alan TR kalır', (
    tester,
  ) async {
    const translated = MovementProgram(
      id: 'sabah',
      title: 'sabah açılışı',
      description: 'Üç kısa seans.',
      sessions: [
        MovementSession(
          id: 's1',
          title: 'boyun ve omuz',
          videoUrl: 'https://v/s1.mp4',
          minutes: 6,
        ),
      ],
      en: MovementTranslation(
        title: 'morning opener',
        sessionTitles: {'s1': 'neck and shoulders'},
      ),
    );

    await pump(tester, p: translated, locale: const Locale('en'));

    expect(find.text('morning opener'), findsOneWidget);
    expect(find.text('neck and shoulders'), findsOneWidget);
    // Çevirisi olmayan açıklama Türkçe kalır — boş ekran yerine.
    expect(find.text('Üç kısa seans.'), findsOneWidget);
  });
}
