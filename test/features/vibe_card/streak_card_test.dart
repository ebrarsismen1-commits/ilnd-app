import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/ilnd/streak_copy.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/features/vibe_card/streak_card_widget.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Faz 3c — streak eşik kartı: 7/30/100 gün eşikleri "bunu az insan yapar"
/// gururunu paylaşılabilir karta çevirir; kod rozeti davetiye işlevi görür.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  final l10n = lookupAppLocalizations(const Locale('tr'));

  group('StreakCopy.milestoneHeadline', () {
    test('eşikler: 7 hafta, 30 ay, 100 yüz; altı null', () {
      expect(StreakCopy.milestoneHeadline(days: 6, l10n: l10n), isNull);
      expect(
        StreakCopy.milestoneHeadline(days: 7, l10n: l10n),
        l10n.streakCardHeadlineWeek,
      );
      expect(
        StreakCopy.milestoneHeadline(days: 45, l10n: l10n),
        l10n.streakCardHeadlineMonth,
      );
      expect(
        StreakCopy.milestoneHeadline(days: 120, l10n: l10n),
        l10n.streakCardHeadlineHundred,
      );
    });
  });

  testWidgets('kartta gün sayısı, eşik başlığı ve kod rozeti', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StreakCardWidget(
            days: 30,
            userName: 'Zeynep',
            p: AppPalette.light,
            referralCode: 'ABC123',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('30'), findsOneWidget);
    expect(find.text(l10n.streakCardHeadlineMonth), findsOneWidget);
    expect(find.text(l10n.vibeCardInviteCode('ABC123')), findsOneWidget);
    expect(find.text('Zeynep · ilnd.app'), findsOneWidget);
  });
}
