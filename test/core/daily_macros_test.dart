import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/repositories/food_repository.dart';

/// Bugünün makro toplamı iki yüzeyde birden görünüyor: Takip ekranı ve
/// Bugün'deki takip kartı ("1240 kcal · 750 ml · 2 alışkanlık"). Yanlış
/// toplama, kullanıcının kendi verisine güvenini bitirir.
FoodEntry _e({
  required int kcal,
  int protein = 0,
  int carbs = 0,
  int fat = 0,
  String id = 'x',
}) => FoodEntry(
  id: id,
  yemekAdi: 'öğün',
  kalori: kcal,
  protein: protein,
  karbonhidrat: carbs,
  yag: fat,
  createdAt: DateTime(2026, 8, 11, 12),
);

void main() {
  group('DailyMacros.fromEntries', () {
    test('kayıt yokken her şey sıfırdır', () {
      final m = DailyMacros.fromEntries(const []);
      expect(m.kalori, 0);
      expect(m.protein, 0);
      expect(m.karbonhidrat, 0);
      expect(m.yag, 0);
    });

    test('tüm alanları ayrı ayrı toplar', () {
      final m = DailyMacros.fromEntries([
        _e(kcal: 520, protein: 30, carbs: 60, fat: 18, id: 'a'),
        _e(kcal: 720, protein: 25, carbs: 90, fat: 22, id: 'b'),
      ]);
      expect(m.kalori, 1240);
      expect(m.protein, 55);
      expect(m.karbonhidrat, 150);
      expect(m.yag, 40);
    });

    test('makrosu bilinmeyen öğün toplamı bozmaz', () {
      // Yemek analizi bazen yalnız kaloriyi çıkarabiliyor; eksik makro
      // toplamı null/NaN'a çevirmemeli.
      final m = DailyMacros.fromEntries([
        _e(kcal: 300, id: 'a'),
        _e(kcal: 200, protein: 10, id: 'b'),
      ]);
      expect(m.kalori, 500);
      expect(m.protein, 10);
      expect(m.karbonhidrat, 0);
    });

    test('tek öğün kendi değerlerini verir', () {
      final m = DailyMacros.fromEntries([
        _e(kcal: 410, protein: 21, carbs: 44, fat: 12),
      ]);
      expect(m.kalori, 410);
      expect(m.protein, 21);
      expect(m.karbonhidrat, 44);
      expect(m.yag, 12);
    });
  });
}
