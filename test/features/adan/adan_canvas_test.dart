import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/features/adan/adan_model.dart';
import 'package:ilnd_app/features/adan/adan_screen.dart';
import 'package:ilnd_app/features/adan/island_painter.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Ada illüstrasyonu (topografik yön) — çizim iki ölçekte, iki palette ve
/// her kazanım durumunda ayakta kalmalı.
///
/// Testin varlık sebebi Sert Kural #14'ün sınıfı: sabit boyut varsayan
/// görsel widget dar viewport'ta taşıyor. Ada iki yerde birden yaşıyor
/// (Bugün 150, Adan 330), yani aynı hata iki ekranı birden bozardı.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pumpCanvas(
    WidgetTester tester, {
    required IslandState state,
    required AppPalette p,
    double width = 320,
    double height = 150,
    bool showWordmark = true,
  }) async {
    tester.view.physicalSize = Size(width, height + 40);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              height: height,
              child: AdanCanvas(state: state, p: p, showWordmark: showWordmark),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('AdanCanvas', () {
    testWidgets('dar viewport, 150 yükseklik: taşma yok', (tester) async {
      await pumpCanvas(
        tester,
        state: const IslandState(earned: {'lantern', 'pine'}),
        p: AppPalette.light,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('Adan ekranı ölçüsünde (330) de taşmıyor', (tester) async {
      await pumpCanvas(
        tester,
        state: const IslandState(earned: {'lantern'}),
        p: AppPalette.dark,
        width: 320,
        height: 330,
        showWordmark: false,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('ekran okuyucu etiketi öğe sayısını söyler', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCanvas(
        tester,
        state: const IslandState(earned: {'lantern', 'pine', 'oven'}),
        p: AppPalette.light,
      );

      final l10n = lookupAppLocalizations(const Locale('tr'));
      expect(
        find.bySemanticsLabel(l10n.adanCanvasSemantics(3)),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('hiç öğe yokken boş durum metni, suçlayıcı değil', (
      tester,
    ) async {
      await pumpCanvas(tester, state: const IslandState(), p: AppPalette.light);
      final l10n = lookupAppLocalizations(const Locale('tr'));
      expect(find.text(l10n.adanEmptyProgress), findsOneWidget);
    });

    testWidgets('uzun öğe adı tek satırda kırpılır', (tester) async {
      await pumpCanvas(
        tester,
        state: const IslandState(
          earned: {'lantern', 'pine', 'oven', 'windrose', 'moonlight'},
        ),
        p: AppPalette.light,
        width: 280,
      );
      expect(tester.takeException(), isNull);
      final progress = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) => w is Text && (w.overflow == TextOverflow.ellipsis),
        ),
      );
      expect(progress.maxLines, 1);
    });
  });

  group('IslandPainter', () {
    test('sessiz gün arttıkça zemin suya doğru koyulaşır', () {
      const p = AppPalette.light;
      final clear = IslandPainter.groundColor(p, WaterDepth.clear);
      final deep = IslandPainter.groundColor(p, WaterDepth.deep);
      final deepest = IslandPainter.groundColor(p, WaterDepth.deepest);

      expect(clear, p.accentSoft);
      expect(deep, isNot(clear));
      expect(deepest, isNot(deep));
      // Koyulaşma tek yönlü: her kademe bir öncekinden daha karanlık.
      expect(deep.computeLuminance(), lessThan(clear.computeLuminance()));
      expect(deepest.computeLuminance(), lessThan(deep.computeLuminance()));
    });

    test('yalnız kazanım, derinlik ya da palet değişince yeniden çizer', () {
      const a = IslandPainter(
        state: IslandState(earned: {'lantern'}),
        p: AppPalette.light,
      );
      expect(
        a.shouldRepaint(
          const IslandPainter(
            state: IslandState(earned: {'lantern'}),
            p: AppPalette.light,
          ),
        ),
        isFalse,
      );
      expect(
        a.shouldRepaint(
          const IslandPainter(
            state: IslandState(earned: {'lantern', 'pine'}),
            p: AppPalette.light,
          ),
        ),
        isTrue,
      );
      expect(
        a.shouldRepaint(
          const IslandPainter(
            state: IslandState(earned: {'lantern'}, quietDays: 9),
            p: AppPalette.light,
          ),
        ),
        isTrue,
      );
      expect(
        a.shouldRepaint(
          const IslandPainter(
            state: IslandState(earned: {'lantern'}),
            p: AppPalette.dark,
          ),
        ),
        isTrue,
      );
    });

    testWidgets('altı öğenin hepsi çizilebiliyor, iki palette de', (
      tester,
    ) async {
      final all = kIslandItems.map((i) => i.id).toSet();
      for (final p in [AppPalette.light, AppPalette.dark]) {
        for (final state in [
          const IslandState(),
          IslandState(earned: all),
          IslandState(earned: all, quietDays: 12),
        ]) {
          await pumpCanvas(tester, state: state, p: p, height: 330);
          expect(tester.takeException(), isNull);
        }
      }
    });
  });

  group('WaterDepth', () {
    test('üç kademe, dördüncü yok — sessizlik ceza değil', () {
      expect(const IslandState().water, WaterDepth.clear);
      expect(const IslandState(quietDays: 2).water, WaterDepth.clear);
      expect(const IslandState(quietDays: 3).water, WaterDepth.deep);
      expect(const IslandState(quietDays: 6).water, WaterDepth.deep);
      expect(const IslandState(quietDays: 7).water, WaterDepth.deepest);
      // 40 gün de 400 gün de aynı yerde durur: dip diye bir şey yok.
      expect(const IslandState(quietDays: 400).water, WaterDepth.deepest);
    });
  });
}
