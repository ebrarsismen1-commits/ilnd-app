import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/widgets/breath_ring.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/shimmer.dart';

/// Erişilebilirlik: kullanıcı sistemde "hareketi azalt" dediğinde sürekli ve
/// dekoratif animasyonlar DURMALI. Vestibüler rahatsızlığı olan kullanıcıda
/// kayan/ölçeklenen arayüz baş dönmesi yapar.
///
/// Uygulamada aynı anda dört sürekli hareket vardı (zemin, giriş animasyonu,
/// streak alevi, nefes halkası) ve hiçbiri bu ayarı dinlemiyordu.
///
/// Not: `pumpAndSettle` KULLANILMAZ — bazı ekranlarda sürekli
/// döner, sahne hiç durulmaz (CLAUDE.md #12).
Widget _wrap(Widget child, {required bool reduced}) => ProviderScope(
  child: MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Scaffold(body: child),
    ),
  ),
);

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Entrance', () {
    testWidgets('azaltılmış modda animasyon hiç kurulmaz', (tester) async {
      await tester.pumpWidget(
        _wrap(const Entrance(index: 3, child: Text('içerik')), reduced: true),
      );
      await tester.pump();

      expect(find.text('içerik'), findsOneWidget);
      expect(
        find.ancestor(of: find.text('içerik'), matching: find.byType(Opacity)),
        findsNothing,
        reason: 'Azaltılmış modda giriş animasyonu hiç kurulmamalı',
      );
      // Bekleyen zamanlayıcı da kalmamalı: uzun listede her öğe için boşuna
      // bir timer açmak israftır (kaynakta didChangeDependencies'te kilitli).
    });

    testWidgets('normal modda animasyon sarmalayıcısı vardır', (tester) async {
      await tester.pumpWidget(
        _wrap(const Entrance(child: Text('içerik')), reduced: false),
      );
      await tester.pump();
      expect(
        find.ancestor(of: find.text('içerik'), matching: find.byType(Opacity)),
        findsOneWidget,
      );
      // Zamanlayıcıyı ve 550 ms'lik animasyonu tükete.
      await tester.pump(const Duration(milliseconds: 900));
    });
  });

  group('ShimmerBox', () {
    testWidgets('azaltılmış modda parıltı hiç dönmez', (tester) async {
      await tester.pumpWidget(
        _wrap(const ShimmerBox(width: 100, height: 20), reduced: true),
      );
      await tester.pump();

      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(ShimmerBox),
          matching: find.byType(Container),
        ),
      );
      final deco = box.decoration as BoxDecoration;
      expect(
        deco.gradient,
        isNull,
        reason: 'Sürekli parıltı dekoratif — azaltılmış modda düz zemin kalır',
      );
      // Sonsuz tekrar eden denetleyici de başlamamalı: başlarsa hem pil
      // yakar hem testte sahne hiç durulmaz (CLAUDE.md #12 komşusu).
    });

    testWidgets('normal modda degrade vardır', (tester) async {
      await tester.pumpWidget(
        _wrap(const ShimmerBox(width: 100, height: 20), reduced: false),
      );
      await tester.pump();

      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(ShimmerBox),
          matching: find.byType(Container),
        ),
      );
      expect((box.decoration as BoxDecoration).gradient, isNotNull);
    });
  });

  testWidgets('BreathRing azaltılmış modda ölçek sabit kalır', (tester) async {
    await tester.pumpWidget(_wrap(const BreathRing(size: 44), reduced: true));
    await tester.pump();

    // BreathRing içinde birden çok ScaleTransition var (dış halka + iç daire).
    final t = tester.widget<ScaleTransition>(
      find.byType(ScaleTransition).first,
    );
    expect(t.scale.value, 1.0);
    await tester.pump(const Duration(milliseconds: 900));
    expect(
      t.scale.value,
      1.0,
      reason: 'Nefes ritmi dekoratif — azaltılmış modda durmalı',
    );
  });
}
