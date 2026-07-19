import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/repositories/vibe_card_repository.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/features/vibe_card/vibe_card_widget.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Paylaşılan her kart aynı zamanda bir davetiyedir: kullanıcının referral
/// kodu kartın görseline basılır (Faz 3 — viral döngü). Kod yoksa (eski
/// hesap / ensure başarısız) kart kodsuz ama kırılmadan çizilir.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  final data = VibeCardData(
    journalCount: 3,
    habitCompletionCount: 5,
    streakDays: 2,
    weekStart: DateTime(2026, 7, 13),
    weekEnd: DateTime(2026, 7, 19),
  );

  Future<void> pumpCard(WidgetTester tester, {required String code}) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VibeCardWidget(
            data: data,
            userName: 'Zeynep',
            p: AppPalette.light,
            referralCode: code,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('referral kodu kartın üzerine basılır', (tester) async {
    await pumpCard(tester, code: 'ABC123');

    final l10n = lookupAppLocalizations(const Locale('tr'));
    expect(find.text(l10n.vibeCardInviteCode('ABC123')), findsOneWidget);
  });

  testWidgets('kod boşken rozet çizilmez, kart kırılmaz', (tester) async {
    await pumpCard(tester, code: '');

    expect(find.textContaining('davet kodum'), findsNothing);
    expect(find.text('Zeynep · ilnd.app'), findsOneWidget);
  });
}
