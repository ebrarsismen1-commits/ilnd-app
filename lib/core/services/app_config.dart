/// Tüm environment değişkenlerini tek yerden oku.
/// Kullanım: `flutter run --dart-define-from-file=.env`
///
/// `fromEnvironment` compile-time sabitler okur, bu yüzden
/// --dart-define-from-file olmadan çalıştırılırsa fallback değerler döner.
abstract final class AppConfig {
  // ── Supabase ────────────────────────────────────────────────────────────────
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

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

  // ── RevenueCat ──────────────────────────────────────────────────────────────
  static const revenueCatApiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
    defaultValue: '',
  );

  // ── Auth köprüsü (Supabase JWT -> Firebase custom token) ──────────────────────
  // functions/index.js'teki mintFirebaseToken endpoint'i. Deploy edilince
  // https://<region>-<project-id>.cloudfunctions.net/mintFirebaseToken olur.
  static const authBridgeUrl = String.fromEnvironment(
    'AUTH_BRIDGE_URL',
    defaultValue: '',
  );

  static bool get isAuthBridgeConfigured => authBridgeUrl.isNotEmpty;

  // ── Diğer Cloud Functions ───────────────────────────────────────────────────
  // Hepsi aynı projeye deploy edilir, bu yüzden authBridgeUrl'in tabanından
  // (https://<region>-<project-id>.cloudfunctions.net/) türetilir — her
  // fonksiyon için ayrı bir env değişkeni eklemeye gerek bırakmaz.
  static String _siblingFunctionUrl(String functionName) {
    if (authBridgeUrl.isEmpty) return '';
    final lastSlash = authBridgeUrl.lastIndexOf('/');
    if (lastSlash == -1) return '';
    return '${authBridgeUrl.substring(0, lastSlash + 1)}$functionName';
  }

  static String get anthropicProxyUrl => _siblingFunctionUrl('anthropicProxy');
  static String get redeemReferralCodeUrl =>
      _siblingFunctionUrl('redeemReferralCode');
  static String get deleteAccountUrl => _siblingFunctionUrl('deleteAccount');

  static bool get isAnthropicProxyConfigured => anthropicProxyUrl.isNotEmpty;

  // ── Validation ──────────────────────────────────────────────────────────────
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get isFirebaseConfigured =>
      firebaseApiKey.isNotEmpty && firebaseProjectId.isNotEmpty;
}
