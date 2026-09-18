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
import 'package:ilnd_app/core/billing/revenue_cat_service.dart';
import 'package:ilnd_app/core/repositories/profile_repository.dart';
import 'package:ilnd_app/core/repositories/referral_repository.dart';
import 'package:ilnd_app/core/services/app_check_headers.dart';
import 'package:ilnd_app/core/services/app_config.dart';
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

/// Oturumdaki kullanıcının uygulamanın ihtiyaç duyduğu kadarı. Eskiden
/// Supabase `User` tipiydi; uygulama yalnız `id`'yi (Firebase uid'i) kullanıyor.
@immutable
class AuthUser {
  const AuthUser({required this.id, this.email});

  factory AuthUser.fromFirebase(fb_auth.User u) =>
      AuthUser(id: u.uid, email: u.email);

  final String id;
  final String? email;
}

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
  final AuthUser user;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Kayıt başarılı ama oturum yok: e-posta doğrulaması zorunlu, kullanıcı
/// mailindeki bağlantıyı onaylayana kadar giriş yapamaz. UI bu durumda
/// "onay maili gönderildi" mesajı gösterir — bu bir hata değildir.
class AuthConfirmEmailPending extends AuthState {
  const AuthConfirmEmailPending(this.email);
  final String email;
}

/// Kullanıcı şifre sıfırlama linkinden geldi: oturum recovery token'ıyla
/// açık ama önce YENİ ŞİFRE belirlenmeli. Firebase'e geçişten sonra (ADR-0010)
/// sıfırlama Firebase'in kendi sayfasında tamamlanıyor ve bu durum üretilmiyor;
/// router kilidi Supabase temizliğinde kaldırılacak. Router bu durumda kullanıcıyı
/// yeni-şifre ekranına kilitler; updatePassword başarılı olunca
/// [AuthAuthenticated]'a geçilir.
class AuthPasswordRecovery extends AuthState {
  const AuthPasswordRecovery(this.user);
  final AuthUser user;
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

/// Testlerin sahte FirebaseAuth vermesi için kanca; üretimde null.
@visibleForTesting
fb_auth.FirebaseAuth? debugFirebaseAuthOverride;

fb_auth.FirebaseAuth get _firebaseAuth =>
    debugFirebaseAuthOverride ?? fb_auth.FirebaseAuth.instance;

/// Firebase oturumundaki uid. Kimlik artık doğrudan Firebase Auth'ta
/// (ADR-0010), yani bu değer [authNotifierProvider]'daki kullanıcıyla aynı
/// anda oluşur; kullanıcıya bağlı Firestore provider'ları yine de ikisini
/// birlikte izler (Sert Kural #2).
final firebaseAuthUidProvider = StreamProvider<String?>(
  (ref) => _firebaseAuth.authStateChanges().map((u) => u?.uid),
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

// ─── Notifier ─────────────────────────────────────────────────────────────────

/// Kimlik Firebase Auth'ta (ADR-0010; eskiden Supabase + köprü, ADR-0001).
///
/// E-posta doğrulaması ZORUNLU: Supabase'teki "Confirm email" davranışı
/// korunur. Firebase doğrulanmamış hesabın oturum açmasını kendiliğinden
/// engellemediği için doğrulanmamış e-posta/şifre oturumu burada
/// kimliksiz sayılır ve kapatılır; sunucu uçları da aynı kuralı uygular
/// (functions/authClaims.js).
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthInitial()) {
    _init();
  }

  final Ref _ref;

  StreamSubscription<fb_auth.User?>? _sub;

  /// Kayıt/giriş akışı doğrulanmamış hesabı kendisi kapatırken true: o
  /// sırada gelen "oturum yok" olayı akışın koyduğu durumu (onay bekleniyor,
  /// hata) ezmesin.
  bool _holdAuthEvents = false;

  fb_auth.FirebaseAuth get _auth => _firebaseAuth;

  /// Uygulamaya girebilir mi? Google/Apple e-postayı zaten doğrulamış
  /// sayılır; yalnız e-posta/şifre hesabı doğrulama bekler.
  static bool _isUsable(fb_auth.User u) =>
      u.emailVerified || u.providerData.any((p) => p.providerId != 'password');

  AuthState _stateFor(fb_auth.User? u) => (u != null && _isUsable(u))
      ? AuthAuthenticated(AuthUser.fromFirebase(u))
      : const AuthUnauthenticated();

  void _init() {
    // Resolve synchronously so the router redirect has a concrete state on
    // first build. Web'de Firebase oturumu diskten asenkron yüklenir; o
    // zaman ilk olay gelene kadar AuthInitial (splash) kalınır.
    final current = _auth.currentUser;
    if (current != null || !kIsWeb) state = _stateFor(current);
    if (state is AuthAuthenticated) {
      unawaited(RevenueCatService.identify(current!.uid));
    }

    // Stay in sync with sign-in/out, token refresh, other tabs, etc.
    _sub = _auth.userChanges().listen((u) {
      if (!mounted || _holdAuthEvents) return;
      final next = _stateFor(u);
      // Akışın bıraktığı mesaj (onay maili gönderildi / hata) ekranda kalsın:
      // kapattığımız doğrulanmamış oturumun olayları akış bittikten SONRA da
      // gelebilir. İkisi de router için zaten kimliksiz durum.
      if (next is AuthUnauthenticated &&
          (state is AuthConfirmEmailPending || state is AuthError)) {
        return;
      }
      final prevUid = switch (state) {
        AuthAuthenticated(:final user) => user.id,
        _ => null,
      };
      state = next;
      if (next is AuthAuthenticated) {
        if (prevUid != next.user.id) {
          // Abonelik hesaba bağlansın: cihaz değişince de aynı hak, aynı
          // kullanım sınırı geçerli olsun.
          unawaited(RevenueCatService.identify(next.user.id));
        }
      } else if (prevUid != null) {
        unawaited(RevenueCatService.forget());
      }
    }, onError: _onAuthStreamError);
  }

  void _onAuthStreamError(Object error, StackTrace stackTrace) {
    debugPrint('[Auth] authStateChanges error: $error\n$stackTrace');
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Her yeni hesap bir referral koduna sahip olsun — fire-and-forget,
  /// girişi engellemesin. Sunucu doğrulanmış oturum istediği için yalnız
  /// uygulamaya girebilen hesapla çağrılır.
  void _ensureReferral(String uid) {
    unawaited(
      ReferralRepository(uid).ensureReferralCode().catchError((e) {
        debugPrint('[Auth] ensureReferralCode failed: $e');
        return '';
      }),
    );
  }

  /// Doğrulanmamış e-posta hesabını kapatır ve onay mailini (yeniden)
  /// gönderir. Mail gönderimi başarısız olsa da oturum kapanır.
  Future<void> _closeUnverified(fb_auth.User user) async {
    try {
      await user.sendEmailVerification(_actionCodeSettings);
    } catch (e) {
      debugPrint('[Auth] sendEmailVerification failed: $e');
    }
    await _auth.signOut();
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  Future<void> signIn(String email, String password) async {
    state = const AuthLoading();
    _holdAuthEvents = true;
    try {
      final res = await _auth
          .signInWithEmailAndPassword(email: email.trim(), password: password)
          .timeout(const Duration(seconds: 15));
      final user = res.user;
      if (user == null) {
        state = const AuthError(AuthErrorCode.generic);
      } else if (!_isUsable(user)) {
        await _closeUnverified(user);
        state = const AuthError(AuthErrorCode.confirmEmail);
      } else {
        state = AuthAuthenticated(AuthUser.fromFirebase(user));
        unawaited(RevenueCatService.identify(user.uid));
        _ensureReferral(user.uid);
      }
    } on fb_auth.FirebaseAuthException catch (e) {
      state = AuthError(_mapError(e));
    } catch (e) {
      debugPrint('[Auth] signIn error: $e');
      state = const AuthError(AuthErrorCode.network);
    } finally {
      _holdAuthEvents = false;
    }
  }

  Future<void> signUp(String email, String password, String name) async {
    state = const AuthLoading();
    _holdAuthEvents = true;
    try {
      final res = await _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          )
          .timeout(const Duration(seconds: 15));
      final user = res.user;
      if (user == null) {
        state = const AuthError(AuthErrorCode.signupFailed);
        return;
      }
      final trimmed = name.trim();
      if (trimmed.isNotEmpty) {
        try {
          await user.updateDisplayName(trimmed);
        } catch (e) {
          debugPrint('[Auth] updateDisplayName failed: $e');
        }
        // Profil adı Firestore users/{uid}'e — oturum kapanmadan ÖNCE
        // (kurallar sahibini ister). Hata repository'de yutulur; onboarding
        // flush'ı adı yeniden yazar.
        await ProfileRepository(
          user.uid,
        ).updateFields({ProfileFields.name: trimmed});
      }
      // Doğrulama zorunlu: onay maili gider, kullanıcı linke tıklayıp giriş
      // yapana kadar uygulamaya giremez. UI "onay maili gönderildi" gösterir.
      await _closeUnverified(user);
      state = AuthConfirmEmailPending(email.trim());
    } on fb_auth.FirebaseAuthException catch (e) {
      state = AuthError(_mapError(e));
    } catch (e) {
      debugPrint('[Auth] signUp error: $e');
      state = const AuthError(AuthErrorCode.signupFailed);
    } finally {
      _holdAuthEvents = false;
    }
  }

  /// Google ile giriş — native hesap seçici (google_sign_in), id_token'ı
  /// Firebase'e devrederek oturum açar. Kullanıcı seçiciyi kapatırsa (iptal)
  /// state sessizce [AuthUnauthenticated]'a döner, hata gösterilmez.
  ///
  /// Ön koşul: Firebase Authentication > Sign-in method > Google aktif ve
  /// AppConfig.googleServerClientId o projenin Web OAuth client ID'si olmalı —
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

      final res = await _auth
          .signInWithCredential(
            fb_auth.GoogleAuthProvider.credential(
              idToken: idToken,
              accessToken: googleAuth.accessToken,
            ),
          )
          .timeout(const Duration(seconds: 15));
      final user = res.user;
      if (user != null) _ensureReferral(user.uid);
      // Başarı state'i auth stream'den otomatik gelir (AuthAuthenticated).
    } on fb_auth.FirebaseAuthException catch (e) {
      state = AuthError(_mapError(e));
    } catch (e) {
      debugPrint('[Auth] signInWithGoogle error: $e');
      state = const AuthError(AuthErrorCode.googleFailed);
    }
  }

  /// Apple ile giriş — Sign in with Apple, id_token'ı Firebase'e devreder.
  /// Nonce, Apple'ın döndürdüğü id_token'ın bu istek için üretildiğini
  /// doğrular (replay saldırılarına karşı): Apple'a hash'i, Firebase'e ham
  /// değeri verilir.
  ///
  /// Ön koşul: Firebase Authentication > Sign-in method > Apple aktif olmalı,
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

      final res = await _auth
          .signInWithCredential(
            fb_auth.OAuthProvider(
              'apple.com',
            ).credential(idToken: idToken, rawNonce: rawNonce),
          )
          .timeout(const Duration(seconds: 15));
      final user = res.user;
      if (user != null) _ensureReferral(user.uid);
      // Başarı state'i auth stream'den otomatik gelir (AuthAuthenticated).
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        // Kullanıcı iptal etti — hata değil, sadece geri dön.
        state = const AuthUnauthenticated();
        return;
      }
      debugPrint('[Auth] signInWithApple authorization error: $e');
      state = const AuthError(AuthErrorCode.appleFailed);
    } on fb_auth.FirebaseAuthException catch (e) {
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
      await _auth.signOut();
      // Başarı state'i auth stream'den otomatik gelir (AuthUnauthenticated).
    } catch (e) {
      debugPrint('[Auth] signOut error: $e');
      // Başarıyı taklit etme: gerçek oturum hâlâ açık olabilir, bunu
      // AuthUnauthenticated'a çevirmek yeniden açılışta yanıltıcı
      // sessiz-yeniden-giriş'e yol açar.
      state = const AuthError(AuthErrorCode.signOutFailed);
    }
  }

  /// Hesabı ve tüm verilerini kalıcı olarak siler.
  ///
  /// functions/index.js'teki deleteAccount (Admin SDK) Firestore alt
  /// ağacını, Storage dosyalarını, Supabase'te kalan eski kaydı ve Firebase
  /// Auth kullanıcısını siler. Bu metod onu çağırıp ardından çıkış yapar.
  /// Başarısız olursa state'i önceki hâline döndürür ve hatayı yeniden
  /// fırlatır — UI bunu yakalayıp kullanıcıya göstermeli.
  Future<void> deleteAccount() async {
    final previousState = state;
    state = const AuthLoading();
    try {
      // Silinecek hesap ekrandaki hesap olmalı (denetim M-8).
      final shown = switch (previousState) {
        AuthAuthenticated(:final user) => user.id,
        _ => null,
      };
      final user = _auth.currentUser;
      if (user == null || user.uid != shown) {
        throw AuthErrorCode.deleteUnavailable;
      }
      final idToken = await user.getIdToken();
      if (idToken == null || !AppConfig.isFunctionsConfigured) {
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

      final deletedUid = user.uid;
      try {
        await _auth.signOut();
      } catch (e) {
        // Kullanıcı sunucuda silindi; yerel oturum zaten geçersiz.
        debugPrint('[Auth] signOut after delete failed: $e');
      }
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

  /// E-posta bağlantılarının (onay, şifre sıfırlama) işlem bittikten sonra
  /// döneceği adres. Bağlantının kendisi Firebase'in barındırdığı işlem
  /// sayfasına gider (şifre orada belirlenir); bu yalnız "devam et" hedefi.
  /// Web'de uygulamanın kendi origin'i; mobilde Firebase özel şemayı kabul
  /// etmediği için null (varsayılan işlem sayfası kendi onayını gösterir).
  /// Web origin'i Firebase Console → Authentication → Authorized domains
  /// listesinde olmalı.
  static fb_auth.ActionCodeSettings? get _actionCodeSettings =>
      kIsWeb ? fb_auth.ActionCodeSettings(url: Uri.base.origin) : null;

  /// Sends a password-reset e-mail via Firebase Auth.
  /// Throws an [AuthErrorCode] on failure — UI localizes it.
  Future<void> resetPassword(String email) async {
    try {
      await _auth
          .sendPasswordResetEmail(
            email: email.trim(),
            actionCodeSettings: _actionCodeSettings,
          )
          .timeout(const Duration(seconds: 15));
    } on fb_auth.FirebaseAuthException catch (e) {
      throw _mapError(e);
    } catch (_) {
      throw AuthErrorCode.resetFailed;
    }
  }

  /// Oturum açıkken yeni şifreyi kaydeder; başarılıysa akış
  /// [AuthAuthenticated]'a kapanır. Hata UI'da lokalize edilir.
  Future<void> updatePassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw AuthErrorCode.updatePasswordFailed;
      await user
          .updatePassword(newPassword)
          .timeout(const Duration(seconds: 15));
      state = AuthAuthenticated(AuthUser.fromFirebase(user));
    } on AuthErrorCode {
      rethrow;
    } on fb_auth.FirebaseAuthException catch (e) {
      throw _mapError(e);
    } catch (_) {
      throw AuthErrorCode.updatePasswordFailed;
    }
  }

  AuthErrorCode _mapError(fb_auth.FirebaseAuthException e) =>
      mapFirebaseAuthError(e);
}

// ── Error mapping ─────────────────────────────────────────────────────────────

/// Firebase Auth hata kodunu locale-bağımsız koda çevirir. Notifier dışında,
/// saf fonksiyon olarak durur ki testlenebilsin (Firebase init gerektirmez).
///
/// E-posta numaralandırma koruması açıkken Firebase yanlış şifre ile olmayan
/// hesabı ayırt etmez (`invalid-credential`). Supabase'ten taşınan
/// kullanıcıların Firebase'de şifresi yok; ilk girişleri de bu koda düşer,
/// bu yüzden [AuthErrorCode.invalidCredentials] metni şifre sıfırlamayı
/// hatırlatır (ADR-0010).
AuthErrorCode mapFirebaseAuthError(fb_auth.FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-credential':
    case 'wrong-password':
    case 'INVALID_LOGIN_CREDENTIALS':
      return AuthErrorCode.invalidCredentials;
    case 'user-not-found':
      return AuthErrorCode.userNotFound;
    case 'email-already-in-use':
    case 'account-exists-with-different-credential':
    case 'credential-already-in-use':
      return AuthErrorCode.emailInUse;
    case 'weak-password':
      return AuthErrorCode.weakPassword;
    case 'invalid-email':
    case 'missing-email':
      return AuthErrorCode.invalidEmail;
    case 'network-request-failed':
      return AuthErrorCode.network;
    case 'requires-recent-login':
      return AuthErrorCode.updatePasswordFailed;
  }
  debugPrint('[Auth] ${e.code}');
  return AuthErrorCode.generic;
}
