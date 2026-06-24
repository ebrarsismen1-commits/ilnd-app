import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

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

    // Stay in sync with token refresh, sign-out from other tabs, etc.
    _sub = _client.auth.onAuthStateChange
        .map<AuthState>((data) => data.session != null
            ? AuthAuthenticated(data.session!.user)
            : const AuthUnauthenticated())
        .listen((s) { if (mounted) state = s; });
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
      final res = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      ).timeout(const Duration(seconds: 15));
      // Stream zaten state'i güncelliyor ama başarı garantisi için:
      if (res.session != null) {
        state = AuthAuthenticated(res.user!);
      } else {
        state = const AuthError('Giriş yapılamadı. E-posta onayı gerekiyor olabilir.');
      }
    } on AuthException catch (e) {
      state = AuthError(_mapError(e));
    } catch (e) {
      debugPrint('[Auth] signIn error: $e');
      state = const AuthError('Bağlantı hatası. İnternet bağlantınızı kontrol edin.');
    }
  }

  Future<void> signUp(String email, String password, String name) async {
    state = const AuthLoading();
    try {
      final res = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'name': name.trim()},
      ).timeout(const Duration(seconds: 15));
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
    } catch (_) {
      state = const AuthUnauthenticated();
    }
  }

  // ── Error mapping ───────────────────────────────────────────────────────────

  String _mapError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login') || msg.contains('invalid email or password')) {
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
