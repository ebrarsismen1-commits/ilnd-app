import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';

/// AnimatedBackground her karede 3 tam ekran gradyan boyar. Web'de
/// (özellikle yazılım-render'lı Chrome) 60fps tam ekran boyama giriş
/// ekranını donduruyordu — lowPower modunda animasyon düşük kare hızına
/// kuantalanır: ardışık karelerde gradyan DEĞİŞMEZ, uzun aralıkta değişir.
void main() {
  Alignment gradientBegin(WidgetTester tester) {
    final box = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((w) => w.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.gradient)
        .whereType<LinearGradient>()
        .first;
    return box.begin as Alignment;
  }

  Future<void> pumpBg(WidgetTester tester, {required bool lowPower}) {
    return tester.pumpWidget(
      MaterialApp(
        home: AnimatedBackground(palette: AppPalette.light, lowPower: lowPower),
      ),
    );
  }

  testWidgets('lowPower: ardışık 16ms karelerde gradyan yeniden boyanmaz', (
    tester,
  ) async {
    await pumpBg(tester, lowPower: true);
    final first = gradientBegin(tester);
    await tester.pump(const Duration(milliseconds: 16));
    expect(gradientBegin(tester), first);

    // Ama animasyon ölü değil — uzun aralıkta akmaya devam eder.
    await tester.pump(const Duration(seconds: 2));
    expect(gradientBegin(tester), isNot(first));
  });

  testWidgets('normal mod: her karede akar (davranış değişmedi)', (
    tester,
  ) async {
    await pumpBg(tester, lowPower: false);
    final first = gradientBegin(tester);
    await tester.pump(const Duration(milliseconds: 16));
    expect(gradientBegin(tester), isNot(first));
  });
}
