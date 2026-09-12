import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:ilnd_app/core/services/app_config.dart';

/// Firebase Analytics üzerine ince bir sarmalayıcı. Tüm growth-funnel
/// event'leri buradan geçer. Analytics çağrıları hiçbir zaman uygulamayı
/// çökertmemeli — her metod try/catch ile korunur.
///
/// Olayların tam sözlüğü: `docs/tr/ANALITIK_SOZLUGU.md`. Yeni olay eklerken
/// oraya da satır eklenir; `test/core/analytics_dictionary_test.dart` bunu
/// zorlar.
abstract final class AnalyticsService {
  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  /// Testlerin olayları yakalaması için takılabilir kanal.
  ///
  /// Üretimde daima `null`, yani olaylar Firebase'e gider. Firebase testte
  /// kurulu olmadığı için [_guard] hatayı yutar ve hiçbir iddia kurulamazdı;
  /// bu kanal olmadan "başarısız analizde tamamlandı olayı atılmamalı" gibi
  /// kurallar test edilemez.
  @visibleForTesting
  static void Function(String name, Map<String, Object?>? params)? testSink;

  static Future<void> initialize() async {
    if (!AppConfig.isFirebaseConfigured) return;
    // Canlı projeye bağlı debug derlemesi geliştirici olaylarıyla gerçek
    // huniyi kirletmesin (denetim C-2).
    final devOnProd = AppConfig.isDebugBuildOnProd(
      isDebug: kDebugMode,
      projectId: AppConfig.firebaseProjectId,
    );
    await _guard(() => _analytics.setAnalyticsCollectionEnabled(!devOnProd));
  }

  static Future<void> setUserId(String? userId) =>
      _guard(() => _analytics.setUserId(id: userId));

  static Future<void> logAppOpen() => _guard(() => _analytics.logAppOpen());

  // ── Onboarding ──────────────────────────────────────────────────────────────

  static Future<void> logOnboardingStarted() => _log('onboarding_started');

  static Future<void> logOnboardingStepCompleted(
    int stepIndex,
    String stepName,
  ) => _log('onboarding_step_completed', {
    'step_index': stepIndex,
    'step_name': stepName,
  });

  static Future<void> logOnboardingAbandonedAtStep(
    int stepIndex,
    String stepName,
  ) => _log('onboarding_abandoned_at_step', {
    'step_index': stepIndex,
    'step_name': stepName,
  });

  static Future<void> logTimeToFirstValue(Duration elapsed) =>
      _log('time_to_first_value', {'seconds': elapsed.inSeconds});

  // ── Paylaşım / referral ─────────────────────────────────────────────────────

  static Future<void> logVibeCardGenerated() => _log('vibe_card_generated');

  static Future<void> logVibeCardShared(String method) =>
      _log('vibe_card_shared', {'platform': method});

  static Future<void> logReferralLinkShared(String method) =>
      _log('referral_link_shared', {'platform': method});

  static Future<void> logReferralSignupCompleted() =>
      _log('referral_signup_completed');

  static Future<void> logReferralRewardClaimed() =>
      _log('referral_reward_claimed');

  // ── Yemek analizi ───────────────────────────────────────────────────────────
  // Çağrı başına en pahalı AI yüzeyi. Üç olay birlikte okunur: başlayan kaç
  // analizin kaçı sonuçlandı, kaçı hangi sebeple düştü. Kaydetme ayrı bir
  // adım, çünkü kullanıcı sonucu görüp vazgeçebiliyor.

  static Future<void> logFoodAnalysisStarted() => _log('food_analysis_started');

  static Future<void> logFoodAnalysisCompleted() =>
      _log('food_analysis_completed');

  /// [reason] bir `FoodAnalysisErrorCode` adıdır, kullanıcı metni DEĞİL.
  static Future<void> logFoodAnalysisFailed(String reason) =>
      _log('food_analysis_failed', {'reason': reason});

  /// [portion] kullanıcının AI tahminine uyguladığı çarpan (0.5 / 1 / 1.5 / 2).
  /// Dağılımı, görsel tahminin sistematik olarak sapıp sapmadığını gösterir.
  static Future<void> logFoodEntrySaved(double portion) =>
      _log('food_entry_saved', {'portion': portion});

  /// Kayıtlı bir öğün takip ekranından düzeltildi.
  ///
  /// [recalculated] ayrımı para sorusudur: malzeme düzeltmek bedavadır,
  /// makroları yeniden hesaplatmak bir analiz hakkı yer. İkisinin oranı,
  /// ücretsiz düzeltmenin kotayı koruyup korumadığını gösterir.
  static Future<void> logFoodEntryEdited({required bool recalculated}) =>
      _log('food_entry_edited', {'recalculated': recalculated});

  // ── Gelir hunisi ────────────────────────────────────────────────────────────
  // Uygulamanın para kazandığı tek yol. Sırayla okunur: limit doldu →
  // paywall görüldü → satın alma başladı → tamamlandı.

  /// [kind] hangi kotanın dolduğu (`UsageKind` adı).
  static Future<void> logFreeLimitReached(String kind) =>
      _log('free_limit_reached', {'kind': kind});

  /// [source] paywall'ın hangi ekrandan açıldığı (food, chat, movement,
  /// plan, profile). Hangi duvarın ödemeye dönüştüğünü bu ayrım söyler.
  static Future<void> logPaywallViewed(String source) =>
      _log('paywall_viewed', {'source': source});

  static Future<void> logPurchaseStarted() => _log('purchase_started');

  static Future<void> logPurchaseCompleted() => _log('purchase_completed');

  /// [reason]: `cancelled` (mağaza iptal/başarısız döndü) veya `error`
  /// (beklenmedik istisna).
  static Future<void> logPurchaseFailed(String reason) =>
      _log('purchase_failed', {'reason': reason});

  /// [restored] geri yüklemenin aktif abonelik bulup bulmadığı.
  static Future<void> logRestoreCompleted(bool restored) =>
      _log('restore_completed', {'restored': restored ? 1 : 0});

  static Future<void> logRestoreFailed() => _log('restore_failed');

  // ── Genel ───────────────────────────────────────────────────────────────────

  /// Yukarıda tanımlanmamış event'ler için genel amaçlı kaçış kapısı.
  ///
  /// Tercih edilmez: buradan geçen ad derleme zamanında değil, ancak panelde
  /// doğrulanır. Yeni bir olay kalıcıysa yukarıya tipli metot ekle.
  static Future<void> logEvent(String name, [Map<String, Object?>? params]) =>
      _log(name, params);

  /// Tüm özel olayların tek çıkış noktası.
  static Future<void> _log(String name, [Map<String, Object?>? params]) {
    final sink = testSink;
    if (sink != null) {
      sink(name, params);
      return Future<void>.value();
    }
    return _guard(
      () => _analytics.logEvent(
        name: name,
        parameters: params?.cast<String, Object>(),
      ),
    );
  }

  /// Ortak try/catch sarmalayıcısı — debug modda hatayı yazdırır, asla fırlatmaz.
  static Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('AnalyticsService hatası: $e');
    }
  }
}
