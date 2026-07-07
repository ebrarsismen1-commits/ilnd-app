import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/widgets/breath_ring.dart';

void main() {
  testWidgets('BreathRing actually animates — not a static circle', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: BreathRing(size: 56))),
      ),
    );

    // "Nefes al" (genişleme) fazının ortasında bir kare al.
    await tester.pump(const Duration(seconds: 2));
    final scaleAt2s = tester
        .widget<ScaleTransition>(
          find.descendant(
            of: find.byType(BreathRing),
            matching: find.byType(ScaleTransition),
          ),
        )
        .scale
        .value;

    // "Nefes ver" (daralma) fazının ortasında başka bir kare al.
    await tester.pump(const Duration(seconds: 3));
    final scaleAt5s = tester
        .widget<ScaleTransition>(
          find.descendant(
            of: find.byType(BreathRing),
            matching: find.byType(ScaleTransition),
          ),
        )
        .scale
        .value;

    // İki kare arasında ölçek gerçekten değişmiş olmalı — sabit kalıyorsa
    // (örn. controller hiç repeat etmiyorsa) bu test kırmızıya düşer.
    expect(scaleAt2s, isNot(equals(scaleAt5s)));

    // 10 saniyelik tam döngü sonunda başlangıç değerine (1.0) yakın dönmeli
    // — "nefes" ritminin gerçekten kapandığının kanıtı.
    await tester.pump(const Duration(seconds: 5));
    final scaleAtFullCycle = tester
        .widget<ScaleTransition>(
          find.descendant(
            of: find.byType(BreathRing),
            matching: find.byType(ScaleTransition),
          ),
        )
        .scale
        .value;
    expect(scaleAtFullCycle, closeTo(1.0, 0.02));
  });

  testWidgets('BreathRing responds to tap when onTap is provided', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: BreathRing(size: 56, onTap: () => tapped = true),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(BreathRing));
    expect(tapped, isTrue);
  });
}
