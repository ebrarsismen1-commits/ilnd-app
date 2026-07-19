import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/features/daily_trio/daily_trio_provider.dart';
import 'package:ilnd_app/features/daily_trio/movement_pool.dart';
import 'package:ilnd_app/features/explore/article_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Faz 2 — Bugünün Üçlüsü: tarif seçimi alerji-önce güvenlik sırasıyla
/// süzülür; tikler günlüktür, tarih değişince kendiliğinden sıfırlanır.
Article _recipe(
  String title, {
  List<String> allergens = const [],
  List<String> diets = const [],
}) => Article(
  id: title,
  title: title,
  category: ArticleCategory.tarif,
  readTime: '10 dk',
  excerpt: '',
  body: const [],
  ingredients: const ['x'],
  steps: const ['y'],
  allergens: allergens,
  diets: diets,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final day = DateTime(2026, 7, 19);

  group('selectRecipeForDay', () {
    final pool = [
      _recipe('menemen', allergens: ['yumurta'], diets: ['vejetaryen']),
      _recipe('mercimek', diets: ['vejetaryen', 'vegan']),
      _recipe('hurma', allergens: ['findik_kabuklu'], diets: ['vegan']),
    ];

    test('alerji süzgeci pazarlıksız: yumurta alerjisi menemeni eler', () {
      for (var i = 0; i < 5; i++) {
        final picked = selectRecipeForDay(
          articles: pool,
          day: day.add(Duration(days: i)),
          diet: null,
          allergies: const ['yumurta'],
        );
        expect(picked!.title, isNot('menemen'));
      }
    });

    test('diyet süzgeci: vegan tercihinde yalnız vegan tarifler döner', () {
      for (var i = 0; i < 5; i++) {
        final picked = selectRecipeForDay(
          articles: pool,
          day: day.add(Duration(days: i)),
          diet: 'vegan',
          allergies: const [],
        );
        expect(picked!.diets, contains('vegan'));
      }
    });

    test('uygun diyet tarifi yoksa diyet gevşer ama alerji gevşemez', () {
      final picked = selectRecipeForDay(
        articles: [
          _recipe('sutlu', allergens: ['sut_laktoz'], diets: ['vejetaryen']),
          _recipe('etli', diets: const []),
        ],
        day: day,
        diet: 'vegan', // hiçbir tarif vegan değil → diyet gevşer
        allergies: const ['sut_laktoz'], // ama sütlü asla önerilmez
      );
      expect(picked!.title, 'etli');
    });

    test('hiç güvenli tarif kalmazsa null (kart gizlenir)', () {
      final picked = selectRecipeForDay(
        articles: [
          _recipe('a', allergens: ['gluten']),
        ],
        day: day,
        diet: null,
        allergies: const ['gluten'],
      );
      expect(picked, isNull);
    });

    test(
      'kArticles gerçek havuzu: her alerji kombinasyonunda seçim güvenli',
      () {
        const allergyKeys = [
          'findik_kabuklu',
          'sut_laktoz',
          'gluten',
          'deniz_urunu',
          'yumurta',
        ];
        for (final allergy in allergyKeys) {
          final picked = selectRecipeForDay(
            articles: kArticles,
            day: day,
            diet: null,
            allergies: [allergy],
          );
          expect(picked, isNotNull);
          expect(picked!.allergens, isNot(contains(allergy)));
        }
      },
    );
  });

  test('movementForDay deterministik ve havuz içinde döner', () {
    final a = movementForDay(day);
    final b = movementForDay(day);
    expect(identical(a, b), isTrue);
    expect(kMovementPool, contains(a));
    // Ertesi gün farklı öğe (havuz > 1).
    expect(movementForDay(day.add(const Duration(days: 1))), isNot(a));
  });

  group('TrioDoneNotifier', () {
    test('toggle günlük kalıcı; başka günün kaydı okunmaz', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final n = TrioDoneNotifier(prefs);
      expect(n.state, isEmpty);

      await n.toggle('move');
      expect(n.state, {'move'});
      await n.toggle('plate');
      expect(n.state, {'move', 'plate'});
      await n.toggle('move');
      expect(n.state, {'plate'});

      // Aynı gün: yeniden kurulunca durum korunur.
      expect(TrioDoneNotifier(prefs).state, {'plate'});

      // Dünün kaydı: tarih eski → boş başlar.
      SharedPreferences.setMockInitialValues({
        'trio_done_date': '2020-01-01',
        'trio_done_items': ['move'],
      });
      final stale = await SharedPreferences.getInstance();
      expect(TrioDoneNotifier(stale).state, isEmpty);
    });
  });
}
