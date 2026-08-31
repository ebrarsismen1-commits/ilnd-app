import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/features/explore/article_detail_screen.dart';
import 'package:ilnd_app/features/explore/article_model.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Kaynakça (2026-08-20). Araştırma temelli yazılar artık gövdenin sonunda
/// kaynak listeliyor. İki sessiz kırılma riski var:
///
/// 1. Kaynak alanı Firestore'dan gelirken eksik/yanlış tipte olabilir —
///    `sources` boşa düşerse ekranda hiçbir şey olmaz, kimse fark etmez.
/// 2. İçerik dosyasına boş ya da yarım künye girilebilir; okuyucuya
///    doğrulayamayacağı bir kaynak göstermek hiç göstermemekten kötüdür.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  final l10n = lookupAppLocalizations(const Locale('tr'));

  group('ArticleSource eşlemesi', () {
    test('künye ve bağlantı okunur', () {
      final s = ArticleSource.fromMap(const {
        'citation': 'Wilding JPH ve ark. NEJM, 2021.',
        'url': 'https://example.org/a',
      });
      expect(s.citation, 'Wilding JPH ve ark. NEJM, 2021.');
      expect(s.url, 'https://example.org/a');
    });

    test('eksik alanlar kırılmıyor (Sert Kural #3)', () {
      final s = ArticleSource.fromMap(const {});
      expect(s.citation, '');
      expect(s.url, isNull);
    });

    test('bağlantısız kaynak toMap sonucuna url anahtarı koymaz', () {
      final m = const ArticleSource(citation: 'Künye, 2020.').toMap();
      expect(m['citation'], 'Künye, 2020.');
      expect(m.containsKey('url'), isFalse);
    });

    test('EN sürümde kaynaklar kayboluyor değil', () {
      // Çeviri yalnız metni değiştirir; kaynakça dile bağlı değildir.
      const article = Article(
        id: 'a',
        title: 'başlık',
        category: ArticleCategory.beslenme,
        readTime: '3 dk',
        excerpt: '',
        body: ['gövde'],
        sources: [ArticleSource(citation: 'Künye, 2021.')],
        en: ArticleTranslation(title: 'title', body: ['body']),
      );
      final en = article.forLocale('en');
      expect(en.sources.single.citation, 'Künye, 2021.');
    });
  });

  group('içerik dosyası', () {
    final raw = File('content/articles.json').readAsStringSync();
    final items = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();

    test('kaynak taşıyan yazı var', () {
      final withSources = items.where(
        (a) => (a['sources'] as List? ?? []).isNotEmpty,
      );
      expect(withSources, isNotEmpty);
    });

    test('her künye dolu ve doğrulanabilir uzunlukta', () {
      for (final a in items) {
        for (final raw in (a['sources'] as List? ?? [])) {
          final s = ArticleSource.fromMap(
            Map<String, dynamic>.from(raw as Map),
          );
          expect(
            s.citation.trim(),
            isNotEmpty,
            reason: '${a['id']}: künyesiz kaynak, okuyucu doğrulayamaz.',
          );
          expect(
            s.citation.trim().length,
            greaterThan(20),
            reason:
                '${a['id']}: künye çok kısa — yazar, dergi ve yıl yazılmalı.',
          );
        }
      }
    });

    test('bağlantı verildiyse http(s)', () {
      for (final a in items) {
        for (final raw in (a['sources'] as List? ?? [])) {
          final url = (raw as Map)['url'] as String?;
          if (url == null) continue;
          expect(
            url.startsWith('https://') || url.startsWith('http://'),
            isTrue,
            reason: '${a['id']}: geçersiz kaynak bağlantısı ($url)',
          );
        }
      }
    });
  });

  group('detay ekranı', () {
    Future<void> pump(WidgetTester tester, Article article) =>
        tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              locale: const Locale('tr'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ArticleDetailScreen(article: article),
            ),
          ),
        );

    const withSources = Article(
      id: 'kaynakli',
      title: 'kaynaklı yazı',
      category: ArticleCategory.beslenme,
      readTime: '5 dk',
      excerpt: 'özet',
      body: ['gövde paragrafı'],
      sources: [
        ArticleSource(citation: 'Wilding JPH ve ark. NEJM, 2021.'),
        ArticleSource(citation: 'Ludwig DS ve ark. JAMA, 2018.'),
      ],
    );

    const withoutSources = Article(
      id: 'kaynaksiz',
      title: 'kaynaksız yazı',
      category: ArticleCategory.gelisim,
      readTime: '3 dk',
      excerpt: 'özet',
      body: ['gövde paragrafı'],
    );

    testWidgets('kaynaklı yazıda künyeler tek tek görünür', (tester) async {
      await pump(tester, withSources);
      await tester.pump();

      expect(find.text(l10n.articleSourcesLabel), findsOneWidget);
      expect(find.text('Wilding JPH ve ark. NEJM, 2021.'), findsOneWidget);
      expect(find.text('Ludwig DS ve ark. JAMA, 2018.'), findsOneWidget);
    });

    testWidgets('kaynaksız yazıda kaynakça bölümü HİÇ çizilmez', (
      tester,
    ) async {
      // Boş bir "KAYNAKLAR" başlığı, olmayan bir titizliğin sözü olurdu.
      await pump(tester, withoutSources);
      await tester.pump();

      expect(find.text(l10n.articleSourcesLabel), findsNothing);
    });
  });
}
