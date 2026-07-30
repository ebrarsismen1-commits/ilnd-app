import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/features/movement/movement_player_screen.dart';
import 'package:ilnd_app/features/movement/movement_program.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('sessionWatchedEnough', () {
    test('videonun %95i izlenince seans tamamlanmış sayılır', () {
      const total = Duration(minutes: 10);
      expect(sessionWatchedEnough(const Duration(minutes: 9), total), isFalse);
      expect(
        sessionWatchedEnough(const Duration(minutes: 9, seconds: 30), total),
        isTrue,
      );
      expect(sessionWatchedEnough(total, total), isTrue);
    });

    test('süre bilinmiyorken tamamlandı denmez', () {
      // initialize() bitmeden position/duration 0'dır; burada "bitti" demek
      // kullanıcı videoyu hiç izlemeden ilerleme yazmak olurdu.
      expect(sessionWatchedEnough(Duration.zero, Duration.zero), isFalse);
    });
  });

  group('MovementPlayerScreen', () {
    const session = MovementSession(
      id: 's1',
      title: 'boyun ve omuz',
      videoUrl: 'https://v/s1.mp4',
      minutes: 6,
    );
    const program = MovementProgram(
      id: 'sabah',
      title: 'sabah açılışı',
      sessions: [session],
    );

    testWidgets('video açılamazsa hata durumu ve tekrar dene gösterir', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MovementPlayerScreen(
              program: program,
              session: session,
              // Gerçek platform oynatıcısı testte yok; kaynak açılamıyormuş
              // gibi davran (bozuk URL / erişilemeyen dosya).
              createController: (_) => throw Exception('no platform'),
            ),
          ),
        ),
      );
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('tr'));
      expect(find.text(l10n.movementPlayerError), findsOneWidget);
      expect(find.text(l10n.movementPlayerRetry), findsOneWidget);
      // Seans başlığı hata durumunda da görünür — kullanıcı nerede olduğunu
      // bilir.
      expect(find.text('boyun ve omuz'), findsOneWidget);
    });
  });
}
