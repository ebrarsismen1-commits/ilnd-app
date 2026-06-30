import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:ilnd_app/core/services/app_config.dart';

/// Firebase Analytics üzerine ince bir sarmalayıcı. Tüm growth-funnel
/// event'leri buradan geçer. Analytics çağrıları hiçbir zaman uygulamayı
/// çökertmemeli — her metod try/catch ile korunur.
abstract final class AnalyticsService {
  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  static Future<void> initialize() async {
    if (!AppConfig.isFirebaseConfigured) return;
    await _guard(() => _analytics.setAnalyticsCollectionEnabled(true));
  }

  static Future<void> setUserId(String? userId) =>
      _guard(() => _analytics.setUserId(id: userId));

  static Future<void> logAppOpen() => _guard(() => _analytics.logAppOpen());

  static Future<void> logOnboardingStarted() =>
      _guard(() => _analytics.logEvent(name: 'onboarding_started'));

  static Future<void> logOnboardingStepCompleted(
    int stepIndex,
    String stepName,
  ) => _guard(
    () => _analytics.logEvent(
      name: 'onboarding_step_completed',
      parameters: {'step_index': stepIndex, 'step_name': stepName},
    ),
  );

  static Future<void> logOnboardingAbandonedAtStep(
    int stepIndex,
    String stepName,
  ) => _guard(
    () => _analytics.logEvent(
      name: 'onboarding_abandoned_at_step',
      parameters: {'step_index': stepIndex, 'step_name': stepName},
    ),
  );

  static Future<void> logTimeToFirstValue(Duration elapsed) => _guard(
    () => _analytics.logEvent(
      name: 'time_to_first_value',
      parameters: {'seconds': elapsed.inSeconds},
    ),
  );

  static Future<void> logVibeCardGenerated() =>
      _guard(() => _analytics.logEvent(name: 'vibe_card_generated'));

  static Future<void> logVibeCardShared(String method) => _guard(
    () => _analytics.logEvent(
      name: 'vibe_card_shared',
      parameters: {'platform': method},
    ),
  );

  static Future<void> logReferralLinkShared(String method) => _guard(
    () => _analytics.logEvent(
      name: 'referral_link_shared',
      parameters: {'platform': method},
    ),
  );

  static Future<void> logReferralSignupCompleted() =>
      _guard(() => _analytics.logEvent(name: 'referral_signup_completed'));

  static Future<void> logReferralRewardClaimed() =>
      _guard(() => _analytics.logEvent(name: 'referral_reward_claimed'));

  /// Yukarıda tanımlanmamış event'ler için genel amaçlı kaçış kapısı.
  static Future<void> logEvent(String name, [Map<String, Object?>? params]) =>
      _guard(
        () => _analytics.logEvent(
          name: name,
          parameters: params?.cast<String, Object>(),
        ),
      );

  /// Ortak try/catch sarmalayıcısı — debug modda hatayı yazdırır, asla fırlatmaz.
  static Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('AnalyticsService hatası: $e');
    }
  }
}
