import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ilnd_app/core/repositories/referral_repository.dart';
import 'package:ilnd_app/core/services/app_check_headers.dart';
import 'package:ilnd_app/core/services/app_config.dart';
import 'package:ilnd_app/core/services/firebase_auth_bridge.dart';

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

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

// ─── Notifier ─────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthInitial()) {
    _init();
  }

  StreamSubscription<AuthState>? _sub;

  SupabaseClient get _client => Supabase.instance.client;

  void _init() {
    // Resolve synchronously so the router redirect has a concrete state on first build.
    final session = _client.auth.currentSession;
    state = session != null
        ? AuthAuthenticated(session.user)
        : const AuthUnauthenticated();
    if (session != null) {
      unawaited(FirebaseAuthBridge.syncFromSupabase(session.accessToken));
    }

    // Stay in sync with token refresh, sign-out from other tabs, etc.
    _sub = _client.auth.onAuthStateChange
        .map<AuthState>(
          (data) => data.session != null
              ? AuthAuthenticated(data.session!.user)
              : const AuthUnauthenticated(),
        )
        .listen((s) {
          if (!mounted) return;
          state = s;
          // Supabase oturumu her (yeniden) kurulduğunda Firebase Auth'u da
          // senkronize tut — request.auth Firestore kurallarında kullanılabilsin.
          final token = _client.auth.currentSession?.accessToken;
          if (s is AuthAuthenticated && token != null) {
            unawaited(FirebaseAuthBridge.syncFromSupabase(token));
          } else if (s is AuthUnauthenticated) {
            unawaited(FirebaseAuthBridge.signOut());
          }
        });
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
          )
          .timeout(const Duration(seconds: 15));
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

      await _client.auth.signOut();
      await FirebaseAuthBridge.signOut();
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

  /// Sends a password-reset e-mail via Supabase.
  /// Throws an [AuthErrorCode] on failure — UI localizes it.
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth
          .resetPasswordForEmail(email.trim())
          .timeout(const Duration(seconds: 15));
    } on AuthException catch (e) {
      throw _mapError(e);
    } catch (_) {
      throw AuthErrorCode.resetFailed;
    }
  }

  // ── Error mapping ───────────────────────────────────────────────────────────

  AuthErrorCode _mapError(AuthException e) {
    final msg = e.message.toLowerCase();
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
}
