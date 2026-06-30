import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
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
  const AuthError(this.message);
  final String message;
}

// ─── Provider ─────────────────────────────────────────────────────────────────

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
        state = const AuthError(
          'Giriş yapılamadı. E-posta onayı gerekiyor olabilir.',
        );
      }
    } on AuthException catch (e) {
      state = AuthError(_mapError(e));
    } catch (e) {
      debugPrint('[Auth] signIn error: $e');
      state = const AuthError(
        'Bağlantı hatası. İnternet bağlantınızı kontrol edin.',
      );
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
        unawaited(ReferralRepository(res.user!.id).ensureReferralCode());
      }
      // signUp state'i auth stream'den otomatik gelir (AuthAuthenticated)
    } on AuthException catch (e) {
      state = AuthError(_mapError(e));
    } catch (e) {
      debugPrint('[Auth] signUp error: $e');
      state = const AuthError('Kayıt oluşturulamadı. Lütfen tekrar deneyin.');
    }
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
      state = const AuthError('Çıkış yapılamadı. Tekrar dener misin?');
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
        throw 'Hesap silme servisi şu an kullanılamıyor.';
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
        throw 'Hesap silinemedi. Tekrar dener misin?';
      }

      await _client.auth.signOut();
      await FirebaseAuthBridge.signOut();
      state = const AuthUnauthenticated();
    } catch (e) {
      debugPrint('[Auth] deleteAccount error: $e');
      final message = e is String ? e : 'Hesap silinemedi. Tekrar dener misin?';
      // Hata durumunda işlem öncesindeki authenticated state'e geri dön —
      // kullanıcı hâlâ giriş yapmış durumda, tekrar deneyebilmeli.
      state = previousState;
      throw message;
    }
  }

  /// Sends a password-reset e-mail via Supabase.
  /// Throws a user-friendly Turkish string on failure.
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth
          .resetPasswordForEmail(email.trim())
          .timeout(const Duration(seconds: 15));
    } on AuthException catch (e) {
      throw _mapError(e);
    } catch (_) {
      throw 'E-posta gönderilemedi. İnternet bağlantınızı kontrol edin.';
    }
  }

  // ── Error mapping ───────────────────────────────────────────────────────────

  String _mapError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login') ||
        msg.contains('invalid email or password')) {
      return 'E-posta veya şifre hatalı.';
    }
    if (msg.contains('email already') || msg.contains('already registered')) {
      return 'Bu e-posta adresi zaten kullanılıyor.';
    }
    if (msg.contains('weak password') || msg.contains('at least 6')) {
      return 'Şifre en az 6 karakter olmalıdır.';
    }
    if (msg.contains('user not found')) {
      return 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.';
    }
    if (msg.contains('network') || msg.contains('socket')) {
      return 'Bağlantı hatası. İnternet bağlantınızı kontrol edin.';
    }
    if (msg.contains('valid') && msg.contains('email')) {
      return 'Geçerli bir e-posta adresi girin.';
    }
    debugPrint('[Auth] ${e.message}');
    return 'Bir hata oluştu. Lütfen tekrar deneyin.';
  }
}
