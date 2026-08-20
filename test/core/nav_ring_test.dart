import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Alt navigasyonun orta halkası nav v2'nin marka jesti. Davranışı bir kez
/// değişti (sohbet → ILND yüzeyi) ve tekrar kaymaması gerekiyor:
/// kısa basış ekle sheet'ini açar, uzun basış sohbete gider. Uzun basış
/// **ikincil** bir kısayoldur — kullanıcı hiç bulamasa bile sohbet, sheet'in
/// ilk maddesi olarak erişilebilir kalır.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('Pressable kısa ve uzun basışı ayırır', (tester) async {
    var taps = 0;
    var longPresses = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: Pressable(
              onTap: () => taps++,
              onLongPress: () => longPresses++,
              child: const SizedBox(width: 80, height: 80),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(Pressable));
    await tester.pump(const Duration(milliseconds: 300));
    expect(taps, 1);
    expect(longPresses, 0, reason: 'Kısa basış kısayolu tetiklememeli');

    await tester.longPress(find.byType(Pressable));
    await tester.pump(const Duration(milliseconds: 300));
    expect(longPresses, 1);
    expect(taps, 1, reason: 'Uzun basış ayrıca kısa basışı çalıştırmamalı');
  });

  testWidgets('yalnız uzun basışı olan Pressable sönük görünmez', (
    tester,
  ) async {
    // Halka gibi çift işlevli öğelerde onTap null bırakılırsa widget
    // "devre dışı" görünüp %45 opaklığa düşüyordu.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Pressable(
            onLongPress: () {},
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    );

    final opacity = tester.widget<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    );
    expect(opacity.opacity, 1.0);
  });
}
