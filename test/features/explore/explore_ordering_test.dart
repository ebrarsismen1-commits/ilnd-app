import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/features/explore/article_model.dart';
import 'package:ilnd_app/features/explore/explore_ordering.dart';

/// Keşfet sırası. Üç şikâyetten doğdu (owner, 2026-08-20):
/// kapak filtreye tepki vermiyordu, hep aynı içerik kapaktaydı ve liste
/// kategori kategori bloklar hâlinde diziliyordu.
Article _a(String id, ArticleCategory c) => Article(
  id: id,
  title: id,
  category: c,
  readTime: '1 dk',
  excerpt: '',
  body: const [],
);

void main() {
  group('interleaveByCategory', () {
    test('kategoriler dönüşümlü diziliyor', () {
      final input = [
        _a('b1', ArticleCategory.beslenme),
        _a('b2', ArticleCategory.beslenme),
        _a('b3', ArticleCategory.beslenme),
        _a('m1', ArticleCategory.meditasyon),
        _a('m2', ArticleCategory.meditasyon),
        _a('t1', ArticleCategory.tarif),
      ];

      final out = interleaveByCategory(input);

      // İlk üç eleman üç FARKLI kategoriden gelmeli: asıl şikâyet buydu.
      final ilkUc = out.take(3).map((a) => a.category).toSet();
      expect(ilkUc.length, 3);
      expect(out.map((a) => a.id).toSet(), input.map((a) => a.id).toSet());
    });

    test('kategori içindeki sıra korunur', () {
      final input = [
        _a('b1', ArticleCategory.beslenme),
        _a('b2', ArticleCategory.beslenme),
        _a('m1', ArticleCategory.meditasyon),
      ];

      final out = interleaveByCategory(input);
      final beslenme = out
          .where((a) => a.category == ArticleCategory.beslenme)
          .map((a) => a.id)
          .toList();

      expect(beslenme, ['b1', 'b2'], reason: 'editoryal öncelik kaybolmamalı');
    });

    test('tek kategori varsa liste bozulmuyor', () {
      final input = [
        _a('b1', ArticleCategory.beslenme),
        _a('b2', ArticleCategory.beslenme),
      ];
      expect(interleaveByCategory(input).map((a) => a.id), ['b1', 'b2']);
    });

    test('boş liste ve tek eleman kırılmıyor', () {
      expect(interleaveByCategory(const []), isEmpty);
      final tek = [_a('x', ArticleCategory.gelisim)];
      expect(interleaveByCategory(tek).single.id, 'x');
    });

    test('hiçbir içerik kaybolmuyor ya da tekrar etmiyor', () {
      final input = [
        for (var i = 0; i < 7; i++) _a('b$i', ArticleCategory.beslenme),
        for (var i = 0; i < 3; i++) _a('m$i', ArticleCategory.meditasyon),
        for (var i = 0; i < 5; i++) _a('g$i', ArticleCategory.gelisim),
      ];
      final out = interleaveByCategory(input);
      expect(out.length, input.length);
      expect(out.map((a) => a.id).toSet().length, input.length);
    });
  });

  group('pickCover', () {
    final havuz = [
      _a('a', ArticleCategory.beslenme),
      _a('b', ArticleCategory.beslenme),
      _a('c', ArticleCategory.beslenme),
    ];

    test('gün değişince kapak da değişiyor', () {
      final gun1 = pickCover(havuz, now: DateTime(2026, 8, 1))!.id;
      final gun2 = pickCover(havuz, now: DateTime(2026, 8, 2))!.id;
      expect(gun1, isNot(gun2), reason: 'en üstte hep aynı içerik olmamalı');
    });

    test('aynı gün içinde kapak sabit', () {
      // Rastgele seçim, sayfa her yenilendiğinde kapağın değişmesi olurdu.
      final ilk = pickCover(havuz, now: DateTime(2026, 8, 5, 9))!.id;
      final sonra = pickCover(havuz, now: DateTime(2026, 8, 5, 21))!.id;
      expect(ilk, sonra);
    });

    test('kapak verilen havuzdan seçiliyor', () {
      // Havuz filtrelenmiş listedir; bir kategoriye basıldığında kapak da
      // o kategoriden gelmeli.
      final tarifler = [
        _a('t1', ArticleCategory.tarif),
        _a('t2', ArticleCategory.tarif),
      ];
      final kapak = pickCover(tarifler, now: DateTime(2026, 8, 3))!;
      expect(kapak.category, ArticleCategory.tarif);
    });

    test('boş havuzda kapak yok', () {
      expect(pickCover(const []), isNull);
    });
  });
}
