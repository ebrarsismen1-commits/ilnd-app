import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/features/explore/article_detail_screen.dart';
import 'package:ilnd_app/features/explore/article_model.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Tarif makaleleri interaktif: malzeme listesi + adım adım pişirme modu.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  final l10n = lookupAppLocalizations(const Locale('tr'));

  const recipe = Article(
    id: 'test-tarif',
    title: 'test tarifi',
    category: ArticleCategory.tarif,
    readTime: '3 dk',
    excerpt: 'kısa özet',
    body: ['giriş paragrafı'],
    ingredients: ['1 su bardağı süt', '1 çay kaşığı bal'],
    steps: ['Sütü ısıt.', 'Balı ekle.', 'Yavaşça iç.'],
  );

  const plainArticle = Article(
    id: 'test-yazi',
    title: 'test yazısı',
    category: ArticleCategory.yazi,
    readTime: '3 dk',
    excerpt: 'kısa özet',
    body: ['paragraf'],
  );

  Future<void> pumpDetail(WidgetTester tester, Article article) {
    return tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArticleDetailScreen(article: article),
        ),
      ),
    );
  }

  testWidgets('tarif detayı malzemeleri ve başla butonunu gösterir', (
    tester,
  ) async {
    await pumpDetail(tester, recipe);
    await tester.pump();

    expect(find.text(l10n.recipeIngredientsTitle), findsOneWidget);
    expect(find.text('1 su bardağı süt'), findsOneWidget);
    expect(find.text(l10n.recipeStartCooking), findsOneWidget);
  });

  testWidgets('tarif olmayan makalede tarif bölümü yok', (tester) async {
    await pumpDetail(tester, plainArticle);
    await tester.pump();

    expect(find.text(l10n.recipeIngredientsTitle), findsNothing);
    expect(find.text(l10n.recipeStartCooking), findsNothing);
  });

  testWidgets('pişirme modu: adımlar sırayla, son adımda afiyet olsun', (
    tester,
  ) async {
    await pumpDetail(tester, recipe);
    await tester.pump();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pump();
    await tester.tap(find.text(l10n.recipeStartCooking));
    await tester.pumpAndSettle();

    // Adım 1.
    expect(find.text(l10n.recipeStepProgress(1, 3)), findsOneWidget);
    expect(find.text('Sütü ısıt.'), findsOneWidget);

    await tester.tap(find.text(l10n.recipeNextButton));
    await tester.pumpAndSettle();
    expect(find.text('Balı ekle.'), findsOneWidget);

    // Geri ok bir adım geri götürür.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Sütü ısıt.'), findsOneWidget);

    // Son adıma ilerle: buton artık afiyet olsun ve dokununca kapanır.
    await tester.tap(find.text(l10n.recipeNextButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.recipeNextButton));
    await tester.pumpAndSettle();
    expect(find.text('Yavaşça iç.'), findsOneWidget);
    expect(find.text(l10n.recipeFinishButton), findsOneWidget);

    await tester.tap(find.text(l10n.recipeFinishButton));
    await tester.pumpAndSettle();
    expect(find.text(l10n.recipeIngredientsTitle), findsOneWidget);
  });
}
