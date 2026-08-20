import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/features/explore/article_model.dart';
import 'package:ilnd_app/features/explore/explore_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Etiket rayı gerçekten filtreliyor mu?
///
/// Pill'ler tasarım geçişinde iki kez yer değiştirdi (önce listenin üstüne,
/// sonra başlığın altına). Yer değişimi sırasında bağlantının kopması sessiz
/// bir hata olurdu: pill boyanır, aktif görünür, liste hiç değişmez.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 2400));
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
  }

  testWidgets('etiket rayı başlığın altında, kapaktan önce', (tester) async {
    await pump(tester);
    final l10n = lookupAppLocalizations(const Locale('tr'));

    final title = find.text(l10n.exploreTitle);
    final allPill = find.text(l10n.exploreFilterAll);
    final moreLabel = find.text(l10n.exploreMoreLabel);

    expect(title, findsOneWidget);
    expect(allPill, findsOneWidget);
    expect(moreLabel, findsOneWidget);

    // Prototipteki sıra: başlık → etiket rayı → kapak → DAHA FAZLA listesi.
    expect(tester.getRect(title).top, lessThan(tester.getRect(allPill).top));
    expect(
      tester.getRect(allPill).top,
      lessThan(tester.getRect(moreLabel).top),
    );
  });

  testWidgets('eşleşme olmayan etiket listeyi sessizce boşaltmaz', (
    tester,
  ) async {
    await pump(tester);
    final l10n = lookupAppLocalizations(const Locale('tr'));

    // Görsel sayısı ölçüt olamaz: ağ yokken CoverImage editoryal degradeye
    // düşer ve hiç Image çizmez. Makale BAŞLIKLARINI sayıyoruz.
    // Kapak (ilk makale) filtrenin dışındadır — ekranın büyük anı hep
    // durur. Sayarken onu hariç tutuyoruz.
    int visibleArticles() => kArticles
        .skip(1)
        .map((a) => a.forLocale('tr').title)
        .where((t) => find.text(t).evaluate().isNotEmpty)
        .length;

    expect(
      visibleArticles(),
      greaterThan(1),
      reason: '"tümü" seçiliyken liste dolu olmalı',
    );

    // Yerleşik içeriğin tamamı "beslenme" (eski tarifler); meditasyon
    // kategorisinde henüz makale YOK. Eskiden bu dokunuş listeyi hiçbir
    // açıklama bırakmadan siliyordu ve ekran bozulmuş gibi görünüyordu.
    await tester.tap(find.text(l10n.exploreFilterMeditation));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(visibleArticles(), 0);
    expect(
      find.text(l10n.exploreFilterEmpty),
      findsOneWidget,
      reason: 'Boş sonuç bir cümleyle açıklanmalı, sessiz kalmamalı',
    );
  });
}
