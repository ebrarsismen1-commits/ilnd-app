import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ilnd_app/core/billing/revenue_cat_service.dart';
import 'package:ilnd_app/core/repositories/referral_repository.dart';
import 'package:ilnd_app/core/services/app_check_headers.dart';
import 'package:ilnd_app/core/services/app_config.dart';
import 'package:ilnd_app/core/services/firebase_auth_bridge.dart';
import 'package:ilnd_app/core/services/local_user_data.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';

// ─── Deep link ────────────────────────────────────────────────────────────────

/// E-posta bağlantılarının (şifre sıfırlama, hesap onayı) mobilde uygulamaya
/// dönmesini sağlayan özel URL şeması.
///
/// Bu üç sabit AndroidManifest.xml intent-filter'ı ve ios/Runner/Info.plist
/// CFBundleURLSchemes girdisiyle BİREBİR aynı olmalı; üçünün tutarlılığını
/// test/features/auth/deep_link_config_test.dart kilitler.
///
/// Şema neden applicationId değil: Android applicationId'si `com.ilnd.ilnd_app`
/// alt çizgi taşıyor, RFC 3986 ise şemada alt çizgiye izin vermiyor. iOS bundle
/// id'si (`com.ilnd.ilndApp`) de Android'inkinden farklı — tek bir `redirectTo`
/// iki platformda da çalışmak zorunda olduğu için platformdan bağımsız,
/// ters-DNS bir şema seçildi.
const authDeepLinkScheme = 'com.ilnd.app';
const authDeepLinkHost = 'login-callback';
const authDeepLinkRedirect = '$authDeepLinkScheme://$authDeepLinkHost';

// ─── State ────────────────────────────────────────────────────────────────────

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final User user;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Kayıt başarılı ama oturum yok: Supabase "Confirm email" açıkken kullanıcı
/// mailindeki bağlantıyı onaylayana kadar giriş yapamaz. UI bu durumda
/// "onay maili gönderildi" mesajı gösterir — bu bir hata değildir.
class AuthConfirmEmailPending extends AuthState {
  const AuthConfirmEmailPending(this.email);
  final String email;
}

/// Kullanıcı şifre sıfırlama linkinden geldi: oturum recovery token'ıyla
/// açık ama önce YENİ ŞİFRE belirlenmeli. Router bu durumda kullanıcıyı
/// yeni-şifre ekranına kilitler; updatePassword başarılı olunca
/// [AuthAuthenticated]'a geçilir.
class AuthPasswordRecovery extends AuthState {
  const AuthPasswordRecovery(this.user);
  final User user;
}

class AuthError extends AuthState {
  const AuthError(this.code);
  final AuthErrorCode code;
}

/// Locale-bağımsız hata kodları — UI katmanı bunları AppLocalizations ile
/// kullanıcının dilinde metne çevirir (bkz. auth_error_l10n.dart).
/// Provider katmanında hardcoded Türkçe metin bırakmak, İngilizce
/// kullanıcıya Türkçe hata göstermek demekti.
enum AuthErrorCode {
  invalidCredentials,
  emailInUse,
  weakPassword,
  userNotFound,
  network,
  invalidEmail,
  generic,
  confirmEmail,
  signupFailed,
  signOutFailed,
  googleFailed,
  appleFailed,
  resetFailed,
  resetLinkInvalid,
  updatePasswordFailed,
  deleteUnavailable,
  deleteFailed,
}

// ─── Provider ─────────────────────────────────────────────────────────────────

/// Firestore kuralları Firebase'in kendi request.auth'una bakar; o oturum
/// FirebaseAuthBridge tamamlanınca açılır. Kullanıcıya bağlı Firestore
/// provider'ları bunu da izler: köprü bitmeden stream açıp permission-denied
/// ile ölmek yerine (Firestore stream'i hatadan sonra kendini yenilemez),
/// köprü girişi geldiğinde otomatik yeniden kurulurlar.
final firebaseAuthUidProvider = StreamProvider<String?>(
  (ref) => fb_auth.FirebaseAuth.instance.authStateChanges().map((u) => u?.uid),
);

/// E-posta linkinden (şifre sıfırlama / hesap onayı) dönen oturum hiç
/// kurulamadığında dolan tek seferlik kanal. Router bu durumda kullanıcıyı
/// giriş ekranında bırakır; ekran burayı dinleyip NEDEN olduğunu söyler.
/// [AuthState] yerine ayrı bir kanal: giriş denemesi hatalarıyla aynı toast
/// yolunu paylaşırsa ikisi birbirini tetikler.
final authLinkErrorProvider = StateProvider<AuthErrorCode?>((ref) => null);

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);

/// E-posta linkindeki tek kullanımlık sıfırlama token’ı.
///
/// Supabase’in varsayılan `{{ .ConfirmationURL }}` şablonu linki önce kendi
/// `/auth/v1/verify` ucuna götürür; o uç token’ı ORADA tüketir ve uygulamaya
/// yalnızca sonucu yollar. Linki bir mail tarayıcısı ya da güvenlik servisi
/// sen tıklamadan önce açarsa token ölür, kullanıcıya
/// `?error=access_denied&error_code=otp_expired` döner (yaşandı).
///
/// `{{ .TokenHash }}` şablonunda link doğrudan uygulamaya gelir ve token
/// YALNIZCA burada, verifyOTP çağrısında tüketilir: linki önden açan bir
/// tarayıcı hiçbir şeyi harcamamış olur.
///
/// Hem query hem fragment okunur; şablonun parametreleri `?` ya da `#`
/// arkasına koyması ayrımı kullanıcıya yansımasın.
@visibleForTesting
String? recoveryTokenHashFrom(Uri uri) {
  final fragment = Uri.splitQueryString(uri.fragment);
  String? param(String key) => uri.queryParameters[key] ?? fragment[key];

  if (param('type') != 'recovery') return null;
  final tokenHash = param('token_hash');
  if (tokenHash == null || tokenHash.isEmpty) return null;
  return tokenHash;
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthInitial()) {
    _init();
  }

  final Ref _ref;

  StreamSubscription<AuthState>? _sub;

  /// token_hash doğrulanırken true. Bu sırada gelen ara olaylar (initialSession
  /// gibi) durumu kimliksize çekip router’ı onboarding duvarına atmasın diye
  /// dinleyici bekletilir; akış passwordRecovery ile kapanır.
  bool _verifyingRecoveryLink = false;

  SupabaseClient get _client => Supabase.instance.client;

  void _init() {
    // Resolve synchronously so the router redirect has a concrete state on first build.
    final session = _client.auth.currentSession;

    // Sıfırlama linki uygulamaya token_hash ile geldiyse önce onu tüket.
    // Oturum zaten varsa (başarılı sıfırlamadan sonra sayfa yenilendi) tekrar
    // denemenin anlamı yok: token tek kullanımlık, ikinci deneme hata verir.
    // Mobilde link https olduğu için tarayıcıda açılır; bu yol web’e özgü.
    final tokenHash = (kIsWeb && session == null)
        ? recoveryTokenHashFrom(Uri.base)
        : null;
    _verifyingRecoveryLink = tokenHash != null;

    // Doğrulama bitene kadar durum AuthInitial kalır, yani kullanıcı splash
    // görür. Aksi hâlde ilk karede kimliksiz sayılıp welcome’a atılır ve
    // doğrulama bitince ekran altından kayardı.
    if (!_verifyingRecoveryLink) {
      state = session != null
          ? AuthAuthenticated(session.user)
          : const AuthUnauthenticated();
    }
    if (session != null) {
      unawaited(FirebaseAuthBridge.syncFromSupabase(session.accessToken));
      unawaited(RevenueCatService.identify(session.user.id));
    }

    // Stay in sync with token refresh, sign-out from other tabs, etc.
    _sub = _client.auth.onAuthStateChange
        .map<AuthState>((data) {
          // Şifre sıfırlama linki: oturum var ama önce yeni şifre belirlenmeli
          // — router kullanıcıyı yeni-şifre ekranına kilitler.
          if (data.event == AuthChangeEvent.passwordRecovery &&
              data.session != null) {
            return AuthPasswordRecovery(data.session!.user);
          }
          return data.session != null
              ? AuthAuthenticated(data.session!.user)
              : const AuthUnauthenticated();
        })
        .listen((s) {
          if (!mounted) return;
          if (_verifyingRecoveryLink && s is! AuthPasswordRecovery) return;
          // Recovery akışı sürerken sonradan gelen tokenRefreshed/signedIn
          // olayları kullanıcıyı yeni-şifre ekranından koparmasın; akış
          // updatePassword ile kapanır.
          if (state is AuthPasswordRecovery && s is AuthAuthenticated) return;
          state = s;
          // Supabase oturumu her (yeniden) kurulduğunda Firebase Auth'u da
          // senkronize tut — request.auth Firestore kurallarında kullanılabilsin.
          final token = _client.auth.currentSession?.accessToken;
          if (s is AuthAuthenticated && token != null) {
            unawaited(FirebaseAuthBridge.syncFromSupabase(token));
            // Abonelik hesaba bağlansın: cihaz değişince de aynı hak, aynı
            // kullanım sınırı geçerli olsun.
            unawaited(RevenueCatService.identify(s.user.id));
          } else if (s is AuthUnauthenticated) {
            unawaited(FirebaseAuthBridge.signOut());
            unawaited(RevenueCatService.forget());
          }
        }, onError: _onAuthStreamError);

    if (tokenHash != null) unawaited(_verifyRecoveryLink(tokenHash));
  }

  /// Sıfırlama linkindeki token_hash’i oturuma çevirir. Başarılı olursa gotrue
  /// passwordRecovery yayar ve durum dinleyicide kurulur; router kullanıcıyı
  /// yeni-şifre ekranına kilitler.
  Future<void> _verifyRecoveryLink(String tokenHash) async {
    try {
      await _client.auth
          .verifyOTP(type: OtpType.recovery, tokenHash: tokenHash)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[Auth] recovery token_hash verify failed: $e');
      if (!mounted) return;
      _ref.read(authLinkErrorProvider.notifier).state =
          AuthErrorCode.resetLinkInvalid;
      state = const AuthUnauthenticated();
    } finally {
      _verifyingRecoveryLink = false;
    }
  }

  /// E-posta linkinden (sıfırlama/onay) dönen oturum kurulamazsa gotrue hatayı
  /// veri değil **stream hatası** olarak yayar. onError yoksa hata zone'a kaçar
  /// ve release'de fatal Crashlytics kaydına dönüşürdü; kullanıcı ise sessizce
  /// giriş ekranında kalırdı.
  ///
  /// Eski sürüm hatayı yalnızca `state is AuthPasswordRecovery` iken işliyordu;
  /// o koşul pratikte hiç oluşmuyor, çünkü recovery durumuna ancak takas
  /// BAŞARILI olunca geçiliyor. Takas patlarsa durum hâlâ kimliksiz oluyor,
  /// koşul tutmuyor ve router kullanıcıyı sessizce giriş ekranına bırakıyordu:
  /// "linke bastım, şifre yenileme yerine giriş ekranı çıkıyor" şikâyetinin
  /// görünen yüzü tam olarak buydu. Artık [authLinkErrorProvider] doluyor ve
  /// giriş ekranı nedeni söylüyor.
  void _onAuthStreamError(Object error, StackTrace stackTrace) {
    debugPrint('[Auth] onAuthStateChange error: $error\n$stackTrace');
    if (!mounted) return;
    // Oturum yokken gelen hata = e-posta linki çözülemedi: kod tükenmiş ya
    // da süresi dolmuş; link, sıfırlamayı isteyenden başka bir
    // cihazda/tarayıcıda açıldığı için PKCE code verifier yerel depoda yok;
    // ya da bir e-posta tarayıcısı linki önden tüketmiş. Oturum VARKEN gelen
    // stream hataları token yenileme/ağ kaynaklı, sıfırlamayla ilgisi yok.
    if (_client.auth.currentSession == null) {
      _ref.read(authLinkErrorProvider.notifier).state =
          AuthErrorCode.resetLinkInvalid;
      state = const AuthUnauthenticated();
      return;
    }
    if (state is AuthPasswordRecovery) {
      state = const AuthError(AuthErrorCode.resetFailed);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  Future<void> signIn(String email, String password) async {
    state = const AuthLoading();
    try {
      final res = await _client.auth
          .signInWithPassword(email: email.trim(), password: password)
          .timeout(const Duration(seconds: 15));
      // Stream zaten state'i güncelliyor ama başarı garantisi için:
      if (res.session != null) {
        state = AuthAuthenticated(res.user!);
      } else {
        state = const AuthError(AuthErrorCode.confirmEmail);
      }
    } on AuthException catch (e) {
      state = AuthError(_mapError(e));
    } catch (e) {
      debugPrint('[Auth] signIn error: $e');
      state = const AuthError(AuthErrorCode.network);
    }
  }

  Future<void> signUp(String email, String password, String name) async {
    state = const AuthLoading();
    try {
      final res = await _client.auth
          .signUp(
            email: email.trim(),
            password: password,
            data: {'name': name.trim()},
            // Onay linki de panel Site URL'inden bağımsız uygulamaya dönsün.
            emailRedirectTo: _emailRedirect,
          )
          .timeout(const Duration(seconds: 15));
      // Confirm email açıkken kullanıcı yaratılır ama oturum verilmez —
      // stream hiç tetiklenmez ve state AuthLoading'de asılı kalırdı.
      // UI'a "onay maili gönderildi" durumunu açıkça bildir.
      if (res.user != null && res.session == null) {
        state = AuthConfirmEmailPending(email.trim());
        return;
      }
      // profiles tablosu opsiyonel — hata verse bile kayıt başarılı sayılır
      if (res.user != null) {
        try {
          await _client.from('profiles').upsert({
            'id': res.user!.id,
            'name': name.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('[Auth] profiles upsert failed: $e');
        }
        // Her yeni kullanıcı kayıt anında bir referral koduna sahip olsun —
        // fire-and-forget, kayıt başarısını engellemesin.
        unawaited(
          ReferralRepository(res.user!.id).ensureReferralCode().catchError((e) {
            debugPrint('[Auth] ensureReferralCode failed: $e');
            return '';
          }),
        );
      }
      // signUp state'i auth stream'den otomatik gelir (AuthAuthenticated)
    } on AuthException catch (e) {
      state = AuthError(_mapError(e));
    } catch (e) {
      debugPrint('[Auth] signUp error: $e');
      state = const AuthError(AuthErrorCode.signupFailed);
    }
  }

  /// Google ile giriş — native hesap seçici (google_sign_in), id_token'ı
  /// Supabase'e devrederek oturum açar. Kullanıcı seçiciyi kapatırsa (iptal)
  /// state sessizce [AuthUnauthenticated]'a döner, hata gösterilmez.
  ///
  /// Ön koşul: Supabase Authentication > Providers > Google aktif ve
  /// AppConfig.googleServerClientId (Web OAuth client ID) dolu olmalı —
  /// bkz. AppConfig.isGoogleSignInConfigured.
  Future<void> signInWithGoogle() async {
    state = const AuthLoading();
    try {
      final googleUser = await GoogleSignIn(
        serverClientId: AppConfig.googleServerClientId,
        scopes: const ['email'],
      ).signIn();
      if (googleUser == null) {
        // Kullanıcı seçiciyi kapattı — hata değil, sadece geri dön.
        state = const AuthUnauthenticated();
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        state = const AuthError(AuthErrorCode.googleFailed);
        return;
      }

      final res = await _client.auth
          .signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: googleAuth.accessToken,
          )
          .timeout(const Duration(seconds: 15));

      if (res.user != null) {
        unawaited(
          ReferralRepository(res.user!.id).ensureReferralCode().catchError((e) {
            debugPrint('[Auth] ensureReferralCode failed: $e');
            return '';
          }),
        );
      }
      // Başarı state'i auth stream'den otomatik gelir (AuthAuthenticated).
    } on AuthException catch (e) {
      state = AuthError(_mapError(e));
    } catch (e) {
      debugPrint('[Auth] signInWithGoogle error: $e');
      state = const AuthError(AuthErrorCode.googleFailed);
    }
  }

  /// Apple ile giriş — Sign in with Apple, id_token'ı Supabase'e devreder.
  /// Nonce, Apple'ın döndürdüğü id_token'ın bu istek için üretildiğini
  /// doğrular (replay saldırılarına karşı) — Supabase dokümantasyonundaki
  /// önerilen akış budur.
  ///
  /// Ön koşul: Supabase Authentication > Providers > Apple aktif olmalı,
  /// iOS hedefinde "Sign in with Apple" capability eklenmiş olmalı.
  Future<void> signInWithApple() async {
    state = const AuthLoading();
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        state = const AuthError(AuthErrorCode.appleFailed);
        return;
      }

      final res = await _client.auth
          .signInWithIdToken(
            provider: OAuthProvider.apple,
            idToken: idToken,
            nonce: rawNonce,
          )
          .timeout(const Duration(seconds: 15));

      if (res.user != null) {
        unawaited(
          ReferralRepository(res.user!.id).ensureReferralCode().catchError((e) {
            debugPrint('[Auth] ensureReferralCode failed: $e');
            return '';
          }),
        );
      }
      // Başarı state'i auth stream'den otomatik gelir (AuthAuthenticated).
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        // Kullanıcı iptal etti — hata değil, sadece geri dön.
        state = const AuthUnauthenticated();
        return;
      }
      debugPrint('[Auth] signInWithApple authorization error: $e');
      state = const AuthError(AuthErrorCode.appleFailed);
    } on AuthException catch (e) {
      state = AuthError(_mapError(e));
    } catch (e) {
      debugPrint('[Auth] signInWithApple error: $e');
      state = const AuthError(AuthErrorCode.appleFailed);
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      // Başarı state'i auth stream'den otomatik gelir (AuthUnauthenticated).
    } catch (e) {
      debugPrint('[Auth] signOut error: $e');
      // Başarıyı taklit etme: gerçek oturum sunucuda hâlâ açık olabilir,
      // bunu AuthUnauthenticated'a çevirmek yeniden açılışta yanıltıcı
      // sessiz-yeniden-giriş'e yol açar.
      state = const AuthError(AuthErrorCode.signOutFailed);
    }
  }

  /// Hesabı ve tüm verilerini kalıcı olarak siler.
  ///
  /// functions/index.js'teki deleteAccount (Admin SDK) Firestore alt
  /// ağacını, Storage dosyalarını, Supabase kullanıcısını ve Firebase Auth
  /// kullanıcısını siler. Bu metod onu çağırıp ardından her iki taraftan da
  /// (Supabase + Firebase) çıkış yapar. Başarısız olursa state'i
  /// [AuthError]'a çevirir ve hatayı yeniden fırlatır — UI bunu yakalayıp
  /// kullanıcıya göstermeli.
  Future<void> deleteAccount() async {
    final previousState = state;
    state = const AuthLoading();
    try {
      // Silinecek hesap ekrandaki hesap olmalı (denetim M-8).
      if (!await FirebaseAuthBridge.ensureSameAccount(
        _client.auth.currentUser?.id,
      )) {
        throw AuthErrorCode.deleteUnavailable;
      }
      final idToken = await fb_auth.FirebaseAuth.instance.currentUser
          ?.getIdToken();
      if (idToken == null || !AppConfig.isAuthBridgeConfigured) {
        throw AuthErrorCode.deleteUnavailable;
      }

      final response = await http
          .post(
            Uri.parse(AppConfig.deleteAccountUrl),
            headers: {
              'Authorization': 'Bearer $idToken',
              ...await appCheckHeaders(),
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw AuthErrorCode.deleteFailed;
      }

      final deletedUid = fb_auth.FirebaseAuth.instance.currentUser?.uid;
      await _client.auth.signOut();
      await FirebaseAuthBridge.signOut();
      await _wipeDeletedAccountLocally(deletedUid);
      state = const AuthUnauthenticated();
    } catch (e) {
      debugPrint('[Auth] deleteAccount error: $e');
      final code = e is AuthErrorCode ? e : AuthErrorCode.deleteFailed;
      // Hata durumunda işlem öncesindeki authenticated state'e geri dön —
      // kullanıcı hâlâ giriş yapmış durumda, tekrar deneyebilmeli.
      state = previousState;
      throw code;
    }
  }

  /// Silinen hesabın cihazda kalan izleri (güvenlik denetimi H-3/M-5):
  /// uid'e bağlı sohbet geçmişi ve AI hafızası, kişisel anahtarlar ve
  /// Firestore'un çevrimdışı önbelleği. Her adım kendi try'ında: hesap
  /// sunucuda zaten silindi, burada bir hata kullanıcıya yansıtılmaz.
  Future<void> _wipeDeletedAccountLocally(String? uid) async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      await clearPersonalLocalData(prefs);
      if (uid != null) await clearUidScopedLocalData(prefs, uid);
    } catch (e) {
      debugPrint('[Auth] local wipe failed: $e');
    }
    if (kIsWeb) return;
    try {
      await FirebaseFirestore.instance.terminate();
      await FirebaseFirestore.instance.clearPersistence();
    } catch (e) {
      debugPrint('[Auth] Firestore cache clear failed: $e');
    }
  }

  /// E-posta bağlantılarının (şifre sıfırlama, hesap onayı) dönüş adresi:
  /// web'de uygulamanın kendi origin'i, mobilde [authDeepLinkRedirect] özel
  /// şeması. Mobilde bunu göndermek şart — `null` bırakılırsa Supabase panel
  /// Site URL'ini kullanır, link tarayıcıda açılır ve PKCE code verifier
  /// uygulamanın deposunda kaldığı için oturum hiç kurulamaz.
  ///
  /// DİKKAT — bunu göndermek tek başına YETMEZ: Supabase, allowlist'te
  /// olmayan bir `redirect_to` gelirse onu sessizce yok sayıp panel Site
  /// URL'ine düşürür. Bu yüzden sıfırlama ve onay linkleri localhost:3000'e
  /// gidiyordu (iki kez yaşandı). Hem web origin'leri hem de
  /// `$authDeepLinkRedirect` Supabase panelinde Authentication → URL
  /// Configuration → Redirect URLs listesinde kayıtlı olmalı; aksi hâlde
  /// buradaki değer hiç kullanılmaz.
  static String? get _emailRedirect =>
      kIsWeb ? Uri.base.origin : authDeepLinkRedirect;

  /// Sends a password-reset e-mail via Supabase.
  /// Throws an [AuthErrorCode] on failure — UI localizes it.
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth
          .resetPasswordForEmail(email.trim(), redirectTo: _emailRedirect)
          .timeout(const Duration(seconds: 15));
    } on AuthException catch (e) {
      throw _mapError(e);
    } catch (_) {
      throw AuthErrorCode.resetFailed;
    }
  }

  /// Recovery oturumundayken yeni şifreyi kaydeder; başarılıysa akış
  /// [AuthAuthenticated]'a kapanır. Hata UI'da lokalize edilir.
  Future<void> updatePassword(String newPassword) async {
    try {
      final res = await _client.auth
          .updateUser(UserAttributes(password: newPassword))
          .timeout(const Duration(seconds: 15));
      final user = res.user;
      if (user == null) throw AuthErrorCode.updatePasswordFailed;
      state = AuthAuthenticated(user);
    } on AuthErrorCode {
      rethrow;
    } on AuthException catch (e) {
      throw _mapError(e);
    } catch (_) {
      throw AuthErrorCode.updatePasswordFailed;
    }
  }

  AuthErrorCode _mapError(AuthException e) => mapSupabaseAuthError(e);
}

// ── Error mapping ─────────────────────────────────────────────────────────────

/// Supabase auth hatasını locale-bağımsız koda çevirir. Notifier dışında,
/// saf fonksiyon olarak durur ki testlenebilsin (Supabase init gerektirmez).
AuthErrorCode mapSupabaseAuthError(AuthException e) {
  final msg = e.message.toLowerCase();
  if (msg.contains('not confirmed')) {
    // "Email not confirmed" — Confirm email açıkken onaysız girişte döner.
    return AuthErrorCode.confirmEmail;
  }
  if (msg.contains('invalid login') ||
      msg.contains('invalid email or password')) {
    return AuthErrorCode.invalidCredentials;
  }
  if (msg.contains('email already') || msg.contains('already registered')) {
    return AuthErrorCode.emailInUse;
  }
  if (msg.contains('weak password') || msg.contains('at least 6')) {
    return AuthErrorCode.weakPassword;
  }
  if (msg.contains('user not found')) {
    return AuthErrorCode.userNotFound;
  }
  if (msg.contains('network') || msg.contains('socket')) {
    return AuthErrorCode.network;
  }
  if (msg.contains('valid') && msg.contains('email')) {
    return AuthErrorCode.invalidEmail;
  }
  debugPrint('[Auth] ${e.message}');
  return AuthErrorCode.generic;
}
