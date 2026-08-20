import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/services/streak_tracker.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// En uzun seri kullanıcının gurur verisidir: bir kez ulaşılan tepe noktası
/// bir daha DÜŞMEZ. Seri kırıldığında güncel seri sıfırlanır ama "en uzun"
/// olduğu yerde kalır — aksi hâlde ürün, kötü bir haftayı geçmişi silerek
/// cezalandırmış olur (PROJECT_PRINCIPLES: non-preachy).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProviderContainer, SharedPreferences)> setUpContainer([
    Map<String, Object> seed = const {},
  ]) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues(seed);
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return (c, prefs);
  }

  test('ilk gözlem en uzun seriyi kurar', () async {
    final (c, prefs) = await setUpContainer();
    final notifier = c.read(longestStreakProvider.notifier);

    expect(c.read(longestStreakProvider), 0);
    await notifier.observe(5);

    expect(c.read(longestStreakProvider), 5);
    expect(prefs.getInt('longest_streak'), 5);
  });

  test('daha kısa bir seri tepe noktasını DÜŞÜRMEZ', () async {
    final (c, _) = await setUpContainer();
    final notifier = c.read(longestStreakProvider.notifier);

    await notifier.observe(12);
    await notifier.observe(3);

    expect(
      c.read(longestStreakProvider),
      12,
      reason: 'Kötü bir hafta geçmişi silmez',
    );
  });

  test('seri kırılsa bile tepe noktası kalır', () async {
    final (c, prefs) = await setUpContainer();
    final notifier = c.read(longestStreakProvider.notifier);

    await notifier.observe(30);
    await notifier.observe(0); // seri kırıldı

    expect(c.read(longestStreakProvider), 30);
    expect(prefs.getInt('longest_streak'), 30);
  });

  test('kaydedilmiş tepe noktasıyla açılır', () async {
    final (c, _) = await setUpContainer({'longest_streak': 42});
    expect(c.read(longestStreakProvider), 42);
  });

  test('aynı seri tekrar bildirilince yazma yapılmaz', () async {
    final (c, prefs) = await setUpContainer();
    final notifier = c.read(longestStreakProvider.notifier);

    await notifier.observe(7);
    expect(prefs.getInt('last_observed_streak'), 7);

    // Ana ekran her build'de observe çağırabilir; aynı değerde gereksiz
    // disk yazması ve tekrar tekrar analytics event'i olmamalı.
    await notifier.observe(7);
    expect(prefs.getInt('last_observed_streak'), 7);
    expect(c.read(longestStreakProvider), 7);
  });

  test('eşik atlanarak geçilse de çöker gibi davranmaz', () async {
    // Kullanıcı uygulamayı iki hafta açmayıp dönebilir; 0'dan 31'e sıçrama
    // üç milestone'u birden geçer ve bu hata değildir.
    final (c, _) = await setUpContainer();
    await c.read(longestStreakProvider.notifier).observe(31);
    expect(c.read(longestStreakProvider), 31);
  });
}
