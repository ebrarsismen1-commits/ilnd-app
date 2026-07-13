import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/widgets/breath_animation.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Nefes ekranı artık sonsuz döngü değil: süreli seans + bitiş anı.
/// DİKKAT: pumpAndSettle YASAK — BreathAnimation sürekli animasyon oynatır.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  final l10n = lookupAppLocalizations(const Locale('tr'));

  Future<void> pumpScreen(WidgetTester tester) {
    return tester.pumpWidget(
      const MaterialApp(
        locale: Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BreathScreen(p: AppPalette.light),
      ),
    );
  }

  testWidgets('varsayılan 2 dk seans geri sayımla başlar', (tester) async {
    await pumpScreen(tester);
    await tester.pump();

    expect(find.text('2:00'), findsOneWidget);
    expect(find.text(l10n.breathMinutesChip(1)), findsOneWidget);
    expect(find.text(l10n.breathMinutesChip(3)), findsOneWidget);

    // Geri sayım gerçekten akıyor.
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('1:58'), findsOneWidget);
  });

  testWidgets('süre çipi seçimi geri sayımı yeniden başlatır', (tester) async {
    await pumpScreen(tester);
    await tester.pump(const Duration(seconds: 5));

    await tester.tap(find.text(l10n.breathMinutesChip(1)));
    await tester.pump();
    expect(find.text('1:00'), findsOneWidget);
  });

  testWidgets('seans bitince tamamlanma ekranı; bir tur daha çalışır', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.text(l10n.breathMinutesChip(1)));
    await tester.pump();

    // 1 dk seansı bitir.
    await tester.pump(const Duration(seconds: 61));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(l10n.breathDoneTitle), findsOneWidget);
    expect(find.text(l10n.breathCloseButton), findsOneWidget);

    // Bir tur daha → seans başa döner.
    await tester.tap(find.text(l10n.breathAgainButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('1:00'), findsOneWidget);
  });
}
