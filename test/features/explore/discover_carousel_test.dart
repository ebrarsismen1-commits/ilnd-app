import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/features/explore/article_model.dart';
import 'package:ilnd_app/features/explore/discover_article_card.dart';
import 'package:ilnd_app/features/explore/discover_carousel.dart';
import 'package:ilnd_app/features/explore/explore_ordering.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// "Bugün senin için" rafı — Keşfet'in gerçek yazılarını taşır.
///
/// Sert Kural #14: yeni kart dar viewport testiyle gelir. Kartlar sabit
/// yükseklikte olduğu için Dynamic Type de ayrıca ölçülüyor.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Article article(int i) => Article(
    id: 'a$i',
    title: 'yazi $i',
    category: ArticleCategory.values[i % ArticleCategory.values.length],
    readTime: '$i dk',
    excerpt: 'ozet $i',
    body: const ['govde'],
  );

  Future<Article?> pumpRail(
    WidgetTester tester, {
    required Size size,
    int count = 5,
    double textScale = 1.0,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Article? opened;
    const p = AppPalette.light;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            backgroundColor: p.base,
            body: Builder(
              builder: (context) => DiscoverCarousel(
                title: AppLocalizations.of(context)!.discoverTodayTitle,
                articles: [for (var i = 0; i < count; i++) article(i)],
                p: p,
                onOpen: (a) => opened = a,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    return opened;
  }

  testWidgets('gerçek yazıyı gösterir: başlık, kategori, okuma süresi', (
    tester,
  ) async {
    await pumpRail(tester, size: const Size(390, 800));
    final l10n = lookupAppLocalizations(const Locale('tr'));

    expect(find.text(l10n.discoverTodayTitle), findsOneWidget);
    expect(find.text('yazi 0'), findsOneWidget);
    expect(find.text('0 dk'), findsOneWidget);
    expect(
      find.text(ArticleCategory.meditasyon.tag.toUpperCase()),
      findsOneWidget,
    );
  });

  testWidgets('karta dokunmak o yazıyı açar', (tester) async {
    Article? opened;
    const p = AppPalette.light;
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => DiscoverCarousel(
                title: 'raf',
                articles: [article(0), article(1)],
                p: p,
                onOpen: (a) => opened = a,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.byType(DiscoverArticleCard).first);
    await tester.pump();
    expect(opened?.id, 'a0');
  });

  testWidgets('raf yatay kayar; sağdaki kartın ucu görünür', (tester) async {
    const width = 390.0;
    await pumpRail(tester, size: const Size(width, 800));

    // İkinci kart ekranın içinde başlar ama sağ kenarı taşar: kullanıcı
    // rafın devam ettiğini görür.
    final second = tester.getRect(find.byType(DiscoverArticleCard).at(1));
    expect(second.left, lessThan(width));
    expect(second.right, greaterThan(width - 40));

    expect(find.text('yazi 4'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('yazi 4'), findsOneWidget);
  });

  testWidgets('dar viewport 320px: kart taşmaz', (tester) async {
    await pumpRail(tester, size: const Size(320, 800));
    expect(tester.takeException(), isNull);
  });

  testWidgets('metin ölçeği 1.5: kart büyür, içerik taşmaz', (tester) async {
    await pumpRail(tester, size: const Size(390, 900), textScale: 1.5);
    expect(tester.takeException(), isNull);

    final card = tester.getRect(find.byType(DiscoverArticleCard).first);
    expect(
      card.height,
      greaterThan(220),
      reason: 'Dynamic Type açıkken kart sabit yükseklikte kalamaz',
    );
  });

  testWidgets('yazı yoksa raf hiç çizilmez', (tester) async {
    await pumpRail(tester, size: const Size(390, 800), count: 0);
    expect(find.byType(DiscoverArticleCard), findsNothing);
    expect(
      find.text(lookupAppLocalizations(const Locale('tr')).discoverTodayTitle),
      findsNothing,
    );
  });

  group('pickDaily', () {
    final pool = [for (var i = 0; i < 10; i++) article(i)];

    test('gün içinde sabit, günler arasında kayar', () {
      final a = pickDaily(pool, now: DateTime(2026, 9, 7, 8));
      final b = pickDaily(pool, now: DateTime(2026, 9, 7, 23));
      final c = pickDaily(pool, now: DateTime(2026, 9, 8, 8));

      expect(a.map((e) => e.id), b.map((e) => e.id));
      expect(a.map((e) => e.id), isNot(c.map((e) => e.id)));
    });

    test('aynı yazıyı iki kez vermez ve havuzu aşmaz', () {
      final short = pool.take(3).toList();
      final picked = pickDaily(short, now: DateTime(2026, 9, 7));
      expect(picked, hasLength(3));
      expect(picked.map((e) => e.id).toSet(), hasLength(3));
    });

    test('boş havuz boş döner', () {
      expect(pickDaily(const [], now: DateTime(2026, 9, 7)), isEmpty);
    });
  });
}
