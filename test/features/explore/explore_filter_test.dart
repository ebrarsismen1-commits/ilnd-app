import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/features/explore/article_model.dart';
import 'package:ilnd_app/features/explore/explore_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';

/// Etiket rayı gerçekten filtreliyor mu?
///
/// Pill'ler tasarım geçişinde iki kez yer değiştirdi (önce listenin üstüne,
/// sonra başlığın altına). Yer değişimi sırasında bağlantının kopması sessiz
/// bir hata olurdu: pill boyanır, aktif görünür, liste hiç değişmez.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        // Keşfet artık onboarding hedeflerini okuyor (kişiselleştirilmiş
        // sıralama), yani SharedPreferences'a bağımlı.
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
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
    //
    // Kapak filtrenin dışındadır, ekranın büyük anı hep durur. Eskiden kapak
    // listenin ilk yazısıydı ve `skip(1)` ile eleniyordu; 2026-08-31'den beri
    // dakikaya bağlı olarak dönüyor (explore_feed.dart), yani hangi yazının
    // kapak olduğu zamana bağlı. Testin hangi dakikada koştuğuna bağlı bir
    // sayı beklemek onu kırılgan yapardı, bu yüzden "kapak kadar" tolerans
    // bırakılıyor.
    int visibleArticles() => kArticles
        .map((a) => a.forLocale('tr').title)
        .where((t) => find.text(t).evaluate().isNotEmpty)
        .length;

    expect(
      visibleArticles(),
      greaterThan(2),
      reason: '"tümü" seçiliyken liste dolu olmalı',
    );

    // Yerleşik içeriğin tamamı "beslenme" (eski tarifler); meditasyon
    // kategorisinde henüz makale YOK. Eskiden bu dokunuş listeyi hiçbir
    // açıklama bırakmadan siliyordu ve ekran bozulmuş gibi görünüyordu.
    await tester.tap(find.text(l10n.exploreFilterMeditation));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      visibleArticles(),
      lessThanOrEqualTo(1),
      reason: 'yalnız kapak kalabilir, liste boşalmış olmalı',
    );
    expect(
      find.text(l10n.exploreFilterEmpty),
      findsOneWidget,
      reason: 'Boş sonuç bir cümleyle açıklanmalı, sessiz kalmamalı',
    );
  });
}
