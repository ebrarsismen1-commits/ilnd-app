import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/features/explore/explore_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Sabit yükseklikli editoryal yüzeyler değişken içerikle taşmamalı.
///
/// Sert Kural #14'ün (paylaşılabilir kart sabit boyut varsayamaz) aynı sınıfı,
/// başka yüzeylerde: Bugün'ün 300px okuma kartı ve Keşfet'in 400px kapağı.
/// İkisi de içeriği dışarıdan alıyor — Bugün'ünki her gün dönüyor
/// (`kArticles[day % length]`), Keşfet'inki Firestore'dan geliyor.
///
/// Hata 2026-08-20'de gerçekten oldu: o günün makalesi uzun başlıklıydı ve
/// okuma kartı 29px taştı. Testler o güne kadar yeşildi, çünkü hangi
/// makalenin çizildiği TAKVİME bağlıydı — dar ekran testi olmadığı için de
/// sarma kaynaklı taşma hiç görünmemişti.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  // Dar telefon (320), yaygın telefon (375), geniş telefon (420).
  for (final width in const [320.0, 375.0, 420.0]) {
    testWidgets('Keşfet kapağı ${width.toInt()}px genişlikte taşmaz', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            locale: Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ExploreScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // Taşma debug'da FlutterError olarak yükselir; sessizce geçmemeli.
      expect(
        tester.takeException(),
        isNull,
        reason: '${width.toInt()}px genişlikte kapak taşıyor',
      );
    });
  }
}
