import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/features/habits/habits_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Su sayacı "kendiliğinden sıfırlanıyor" diye geldi. İki ayrı kaynağı vardı,
/// ikisi de gün anahtarının notifier kurulurken bir kez hesaplanmasıydı; bu
/// test ikisini de kilitler. Zamana bağlı hatalar sessizce geri gelir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('gece yarısını geçince sayaç yeni günde sıfırdan başlar', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    var now = DateTime(2026, 9, 1, 23, 50);
    final water = WaterNotifier(prefs, clock: () => now);
    await water.add(500);
    expect(water.state, 500);

    // Uygulama arka planda geceyi geçirdi; öne gelince gün denetlenir.
    now = DateTime(2026, 9, 2, 0, 5);
    water.syncToToday();
    expect(water.state, 0, reason: 'Yeni gün dünün toplamıyla başlamamalı');

    await water.add(250);
    expect(prefs.getInt('water_2026-09-02'), 250);
    expect(
      prefs.getInt('water_2026-09-01'),
      500,
      reason: 'Dünün kaydı bugünün eklemesiyle bozulmamalı',
    );
  });

  test('ekleme diskteki değerin üstüne yapılır, ikinci örnek ezmez', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    DateTime clock() => DateTime(2026, 9, 1, 10);

    final first = WaterNotifier(prefs, clock: clock);
    final second = WaterNotifier(prefs, clock: clock);

    await first.add(250);
    await second.add(250);

    expect(
      prefs.getInt('water_2026-09-01'),
      500,
      reason: 'Sonradan kurulan notifier öncekinin eklemesini silmemeli',
    );
    expect(second.state, 500);
  });

  test('sıfırlama yalnız bugünün kaydını siler', () async {
    SharedPreferences.setMockInitialValues({
      'water_2026-08-31': 1800,
      'water_2026-09-01': 750,
    });
    final prefs = await SharedPreferences.getInstance();

    final water = WaterNotifier(prefs, clock: () => DateTime(2026, 9, 1, 12));
    expect(water.state, 750);

    await water.reset();
    expect(water.state, 0);
    expect(prefs.getInt('water_2026-09-01'), isNull);
    expect(prefs.getInt('water_2026-08-31'), 1800);
  });
}
