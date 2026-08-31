import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/features/explore/article_model.dart';
import 'package:ilnd_app/features/explore/explore_feed.dart';

/// Keşfet'in kapak ve liste sıralaması.
///
/// Üç şikâyetin karşılığı: kapak hep aynı yazıydı (`allArticles.first`),
/// liste konu konu yığılıydı (içerik sprint sprint tohumlandı, ham sıra
/// "15 meditasyon, sonra 12 egzersiz" diye geliyordu) ve kişiselleştirme
/// hiç yoktu.

Article _a(String id, ArticleCategory category) => Article(
  id: id,
  title: id,
  category: category,
  readTime: '2 dk',
  excerpt: '',
  body: const [],
);

/// İçeriğin tohumlandığı hâl: kategoriler arka arkaya bloklar hâlinde.
List<Article> _seededByTopic() => [
  for (var i = 0; i < 4; i++) _a('med$i', ArticleCategory.meditasyon),
  for (var i = 0; i < 3; i++) _a('har$i', ArticleCategory.hareket),
  for (var i = 0; i < 3; i++) _a('bes$i', ArticleCategory.beslenme),
  for (var i = 0; i < 2; i++) _a('ozb$i', ArticleCategory.ozBakim),
];

void main() {
  group('liste karması', () {
    test('aynı konu arka arkaya yığılmaz', () {
      final feed = orderedFeed(library: _seededByTopic(), goals: const []);

      // Ham sırada ilk dört yazı da meditasyondu. Dönüşümlü dizilimde
      // ardışık iki yazının kategorisi aynı olmamalı (kovalar tükenene
      // kadar; sonda tek kategori kalabilir).
      var repeats = 0;
      for (var i = 1; i < 4; i++) {
        if (feed[i].category == feed[i - 1].category) repeats++;
      }
      expect(repeats, 0, reason: 'listenin başında konu tekrarı olmamalı');
    });

    test('hiçbir yazı kaybolmaz, çoğalmaz', () {
      final library = _seededByTopic();
      final feed = orderedFeed(library: library, goals: const []);

      expect(feed.length, library.length);
      expect(feed.map((a) => a.id).toSet(), library.map((a) => a.id).toSet());
    });

    test('sıralama deterministik: aynı girdi aynı çıktı', () {
      final a = orderedFeed(library: _seededByTopic(), goals: const []);
      final b = orderedFeed(
        library: _seededByTopic().reversed.toList(),
        goals: const [],
      );
      expect(
        a.map((x) => x.id).toList(),
        b.map((x) => x.id).toList(),
        reason: 'Firestore sırası değişse de liste sabit kalmalı',
      );
    });

    test('boş kütüphane boş liste verir', () {
      expect(orderedFeed(library: const [], goals: const []), isEmpty);
    });
  });

  group('kişiselleştirme', () {
    test('ilgi alanı listenin başına gelir', () {
      final feed = orderedFeed(
        library: _seededByTopic(),
        goals: const ['daha_fazla_hareket'],
      );
      expect(feed.first.category, ArticleCategory.hareket);
    });

    test('ilgi alanı FİLTRE DEĞİL: diğer konular da listede kalır', () {
      final feed = orderedFeed(
        library: _seededByTopic(),
        goals: const ['daha_fazla_hareket'],
      );
      expect(feed.length, _seededByTopic().length);
      expect(
        feed.map((a) => a.category).toSet().length,
        greaterThan(1),
        reason: 'tek konuya indirgemek keşfeti öldürür',
      );
    });

    test('hedef yoksa kategoriler sabit sırayla dizilir', () {
      final feed = orderedFeed(library: _seededByTopic(), goals: const []);
      expect(feed, isNotEmpty);
      expect(feed.length, _seededByTopic().length);
    });
  });

  group('kapak', () {
    final library = _seededByTopic();
    DateTime at(int minute) => DateTime.utc(2026, 9, 1, 10, minute);

    test('dakikada bir değişir', () {
      final seen = <String>{};
      for (var m = 0; m < 6; m++) {
        seen.add(pickHero(library: library, goals: const [], now: at(m))!.id);
      }
      expect(seen.length, greaterThan(1), reason: 'kapak artık sabit değil');
    });

    test('aynı dakika içinde değişmez', () {
      final a = pickHero(
        library: library,
        goals: const [],
        now: DateTime.utc(2026, 9, 1, 10, 5, 0),
      );
      final b = pickHero(
        library: library,
        goals: const [],
        now: DateTime.utc(2026, 9, 1, 10, 5, 59),
      );
      expect(a!.id, b!.id);
    });

    test('ilgi alanına uyan yazıdan seçer', () {
      for (var m = 0; m < 6; m++) {
        final hero = pickHero(
          library: library,
          goals: const ['kalori_besin_takibi'],
          now: at(m),
        );
        expect(hero!.category, ArticleCategory.beslenme);
      }
    });

    test('eşleşme yoksa tüm kütüphaneye düşer', () {
      final onlyMeditation = [
        _a('m1', ArticleCategory.meditasyon),
        _a('m2', ArticleCategory.meditasyon),
      ];
      final hero = pickHero(
        library: onlyMeditation,
        goals: const ['daha_fazla_hareket'],
        now: at(3),
      );
      expect(hero, isNotNull);
      expect(hero!.category, ArticleCategory.meditasyon);
    });

    test('boş kütüphanede null döner', () {
      expect(pickHero(library: const [], goals: const [], now: at(0)), isNull);
    });

    test('liste sırası değişse de aynı dakikada aynı kapak', () {
      expect(
        pickHero(library: library, goals: const [], now: at(7))!.id,
        pickHero(
          library: library.reversed.toList(),
          goals: const [],
          now: at(7),
        )!.id,
      );
    });
  });
}
