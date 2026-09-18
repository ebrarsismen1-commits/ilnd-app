import 'package:flutter/foundation.dart';

/// Tüm environment değişkenlerini tek yerden oku.
/// Kullanım: `flutter run --dart-define-from-file=.env`
///
/// `fromEnvironment` compile-time sabitler okur, bu yüzden
/// --dart-define-from-file olmadan çalıştırılırsa fallback değerler döner.
abstract final class AppConfig {
  // ── Firebase ────────────────────────────────────────────────────────────────
  static const firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: '',
  );

  static const firebaseAuthDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: '',
  );

  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: '',
  );

  static const firebaseStorageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: '',
  );

  static const firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '',
  );

  static const firebaseAppId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '',
  );

  // ── Google Sign-In ──────────────────────────────────────────────────────────
  // Firebase projesinin "Web client" OAuth ID'si (Firebase Console →
  // Authentication → Google sağlayıcısı açılınca oluşur). google_sign_in
  // paketi Android/iOS istemci ID'lerini google-services.json /
  // GoogleService-Info.plist'ten okur; bu, Firebase'in id_token'ı
  // doğrulayabilmesi için gereken "audience" değeridir.
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  static bool get isGoogleSignInConfigured => googleServerClientId.isNotEmpty;

  // ── RevenueCat ──────────────────────────────────────────────────────────────
  static const revenueCatApiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
    defaultValue: '',
  );

  // ── App Check (web) ─────────────────────────────────────────────────────────
  // reCAPTCHA v3 site anahtarı. Android/iOS'ta Play Integrity/App Attest
  // otomatik çalışır ama WEB için bu anahtar şart — boşken web'de geçerli
  // App Check token'ı üretilemez, dolayısıyla fonksiyonlarda enforcement
  // AÇILAMAZ (açılırsa web kullanıcıları tamamen kilitlenir). Anahtar Firebase
  // Console → App Check → Web'den alınır ve .env'e RECAPTCHA_SITE_KEY olarak
  // eklenir.
  static const recaptchaSiteKey = String.fromEnvironment(
    'RECAPTCHA_SITE_KEY',
    defaultValue: '',
  );

  static bool get isWebAppCheckConfigured => recaptchaSiteKey.isNotEmpty;

  // ── Cloud Functions ─────────────────────────────────────────────────────────
  // Hepsi aynı projeye deploy edilir: https://<region>-<project-id>.cloudfunctions.net/
  // FUNCTIONS_BASE_URL bu taban. Eski .env'ler yalnız AUTH_BRIDGE_URL
  // (…/mintFirebaseToken) taşıyor; köprü kalktı (ADR-0010) ama taban oradan
  // da türetilebilsin ki .env güncellenmeden derlenen sürüm AI/davet/hesap
  // silmeyi sessizce kaybetmesin.
  static const _functionsBaseUrl = String.fromEnvironment(
    'FUNCTIONS_BASE_URL',
    defaultValue: '',
  );

  static const _legacyAuthBridgeUrl = String.fromEnvironment(
    'AUTH_BRIDGE_URL',
    defaultValue: '',
  );

  /// Sonu `/` ile biten taban; yapılandırılmamışsa boş.
  @visibleForTesting
  static String functionsBaseFrom({
    required String base,
    required String legacyBridge,
  }) {
    if (base.isNotEmpty) return base.endsWith('/') ? base : '$base/';
    final lastSlash = legacyBridge.lastIndexOf('/');
    if (lastSlash == -1) return '';
    return legacyBridge.substring(0, lastSlash + 1);
  }

  static String get functionsBaseUrl => functionsBaseFrom(
    base: _functionsBaseUrl,
    legacyBridge: _legacyAuthBridgeUrl,
  );

  static bool get isFunctionsConfigured => functionsBaseUrl.isNotEmpty;

  static String _siblingFunctionUrl(String functionName) =>
      isFunctionsConfigured ? '$functionsBaseUrl$functionName' : '';

  static String get anthropicProxyUrl => _siblingFunctionUrl('anthropicProxy');
  static String get redeemReferralCodeUrl =>
      _siblingFunctionUrl('redeemReferralCode');
  static String get deleteAccountUrl => _siblingFunctionUrl('deleteAccount');
  static String get syncIslandItemsUrl =>
      _siblingFunctionUrl('syncIslandItems');
  static String get ensureReferralCodeUrl =>
      _siblingFunctionUrl('ensureReferralCode');

  static bool get isAnthropicProxyConfigured => anthropicProxyUrl.isNotEmpty;

  // ── Validation ──────────────────────────────────────────────────────────────
  static bool get isFirebaseConfigured =>
      firebaseApiKey.isNotEmpty && firebaseProjectId.isNotEmpty;

  // ── Ortam ayrımı (güvenlik denetimi C-2) ────────────────────────────────────
  // Tek bir Firebase projesi var ve `.env` hem debug hem release
  // derlemesine gidiyor: `flutter run` canlı veriye yazıyor. Staging projesi
  // kurulana kadar en azından GÖRÜNÜR olsun: debug derleme canlı projeye
  // bağlıysa ekranda "PROD" bandı çıkar ve analitik toplanmaz.
  static const prodFirebaseProjectIds = {'ilnd-app-8dcbd'};

  /// Debug derleme canlı Firebase projesine mi bağlı?
  static bool isDebugBuildOnProd({
    required bool isDebug,
    required String projectId,
  }) => isDebug && prodFirebaseProjectIds.contains(projectId);
}
