import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/repositories/journal_repository.dart';
import 'package:ilnd_app/features/journal/journal_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Günlük, "ekle" sheet'inden push edilen bir yaprak ekran — sekme değil.
/// Kendi çıkışını taşımazsa web'de dönüş yolu HİÇ kalmıyor (donanım geri
/// tuşu ve kenar kaydırma yok) ve kullanıcı ekranda kilitli kalıyor.
/// Bu test o çıkışı kilitler.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pumpWithJournalPushed(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalEntriesProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const JournalScreen(),
                    ),
                  ),
                  child: const Text('anasayfa'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('anasayfa'));
    // pumpAndSettle KULLANILMAZ: AnimatedBackground sürekli animasyon
    // çalıştırıyor (CLAUDE.md #12), sahne hiç durulmuyor ve test zaman aşımına
    // uğruyor. Sabit süre yeterli — geçiş 300 ms.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('günlükte geri dönüş öğesi var ve ana sayfaya döndürür', (
    tester,
  ) async {
    await pumpWithJournalPushed(tester);

    final l10n = lookupAppLocalizations(const Locale('tr'));
    expect(find.text(l10n.journalTitle), findsOneWidget);
    expect(find.text('anasayfa'), findsNothing);

    // Erişilebilirlik etiketiyle bulunur — ikon değişse de test ayakta kalır.
    final back = find.bySemanticsLabel(l10n.a11yBack);
    expect(
      back,
      findsOneWidget,
      reason: 'Yaprak ekran kendi çıkışını taşımalı; web\'de başka yol yok',
    );

    await tester.tap(back);
    // pumpAndSettle KULLANILMAZ: AnimatedBackground sürekli animasyon
    // çalıştırıyor (CLAUDE.md #12), sahne hiç durulmuyor ve test zaman aşımına
    // uğruyor. Sabit süre yeterli — geçiş 300 ms.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('anasayfa'), findsOneWidget);
    expect(find.text(l10n.journalTitle), findsNothing);
  });
}
