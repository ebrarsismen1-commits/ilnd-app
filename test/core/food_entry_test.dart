import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/repositories/food_repository.dart';

/// Malzeme listesi artık öğünle birlikte kaydediliyor: kullanıcı analizin
/// gördüğünü düzeltiyor ve o düzeltme kayda geçmezse bir sonraki bakışta
/// yok oluyordu. Alan sonradan eklendiği için eski kayıtlarda YOK; okuma
/// bunu hata değil, boş liste saymak zorunda.
void main() {
  FoodEntry entry({List<String> malzemeler = const []}) => FoodEntry(
    id: 'x',
    yemekAdi: 'mercimek çorbası',
    kalori: 240,
    protein: 12,
    karbonhidrat: 30,
    yag: 6,
    createdAt: DateTime(2026, 9, 1, 12),
    malzemeler: malzemeler,
  );

  test('malzemeler kayda yazılır', () {
    final map = entry(malzemeler: ['kırmızı mercimek', 'soğan']).toMap('u1');
    expect(map['malzemeler'], ['kırmızı mercimek', 'soğan']);
  });

  test('malzeme verilmezse liste boştur', () {
    expect(entry().malzemeler, isEmpty);
    expect(entry().toMap('u1')['malzemeler'], isEmpty);
  });
}
