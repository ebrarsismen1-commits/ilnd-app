/// Onboarding başlangıcından ilk değer anına (ilk günlük kaydı) kadar geçen
/// süreyi ölçer. Onboarding tek seferlik, doğrusal bir akış olduğu için
/// statik bir kronometre yeterli — Riverpod/SharedPreferences'a gerek yok.
abstract final class OnboardingTimer {
  static DateTime? _startedAt;

  static void start() => _startedAt = DateTime.now();

  static Duration? elapsed() =>
      _startedAt == null ? null : DateTime.now().difference(_startedAt!);

  static void reset() => _startedAt = null;
}
