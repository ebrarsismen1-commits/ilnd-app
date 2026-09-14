import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/features/ekle/food_analysis.dart';

// Güvenlik denetimi L-5 / M-6: model çıktısı sınırlandırılır; porsiyon
// çarpanı (en fazla 2) sonrası bile Firestore kural sınırı aşılmaz.
void main() {
  Map<String, dynamic> json({
    Object? name = 'Mercimek çorbası',
    num kalori = 180,
    num protein = 9,
    num karb = 27,
    num yag = 4.5,
    List<Object?> malzemeler = const ['mercimek', 'soğan'],
  }) => {
    'yemek_adi': name,
    'kalori': kalori,
    'protein': protein,
    'karbonhidrat': karb,
    'yag': yag,
    'malzemeler': malzemeler,
    'yorum': ' güzel seçim ',
  };

  test('normal yanıt aynen okunur', () {
    final r = FoodResult.fromJson(json());
    expect(r.yemekAdi, 'Mercimek çorbası');
    expect(r.kalori, 180);
    expect(r.yag, 4.5);
    expect(r.malzemeler, ['mercimek', 'soğan']);
    expect(r.yorum, 'güzel seçim');
  });

  test('negatif ve akıl dışı değerler sınırlanır', () {
    final r = FoodResult.fromJson(
      json(kalori: 999999, protein: -20, karb: 1e9, yag: -0.5),
    );
    expect(r.kalori, FoodResult.maxKcal);
    expect(r.protein, 0);
    expect(r.karbonhidrat, FoodResult.maxMacroGrams);
    expect(r.yag, 0);
  });

  test('sonsuz ve NaN değerler sıfıra düşer', () {
    final r = FoodResult.fromJson(
      json(kalori: double.infinity, protein: double.nan),
    );
    expect(r.kalori, 0);
    expect(r.protein, 0);
  });

  test('porsiyon çarpanı (2x) sonrası kural sınırı aşılmaz', () {
    final r = FoodResult.fromJson(json(kalori: 50000, protein: 50000));
    expect(r.kalori * 2, lessThanOrEqualTo(20000));
    expect(r.protein * 2, lessThanOrEqualTo(2000));
  });

  test('uzun ad ve malzeme listesi kısaltılır, boş ve metin olmayan '
      'malzemeler atılır', () {
    final r = FoodResult.fromJson(
      json(
        name: 'x' * 1000,
        malzemeler: [
          '',
          42,
          null,
          'y' * 500,
          for (var i = 0; i < 80; i++) 'm$i',
        ],
      ),
    );
    expect(r.yemekAdi.length, FoodResult.maxNameLength);
    expect(r.malzemeler.length, lessThanOrEqualTo(FoodResult.maxIngredients));
    expect(r.malzemeler.first.length, FoodResult.maxIngredientLength);
    expect(r.malzemeler, isNot(contains('')));
  });
}
