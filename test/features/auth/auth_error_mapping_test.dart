import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

void main() {
  test('"Email not confirmed" → confirmEmail (generic\'e düşmemeli)', () {
    // Supabase, onaylanmamış hesapla girişte bu mesajı döndürür. Genel
    // hataya düşerse kullanıcı neden giremediğini asla anlayamaz.
    expect(
      mapSupabaseAuthError(const AuthException('Email not confirmed')),
      AuthErrorCode.confirmEmail,
    );
  });

  test('bilinen mesajlar doğru kodlara eşlenir', () {
    expect(
      mapSupabaseAuthError(const AuthException('Invalid login credentials')),
      AuthErrorCode.invalidCredentials,
    );
    expect(
      mapSupabaseAuthError(const AuthException('User already registered')),
      AuthErrorCode.emailInUse,
    );
    expect(
      mapSupabaseAuthError(
        const AuthException('Password should be at least 6 characters'),
      ),
      AuthErrorCode.weakPassword,
    );
    expect(
      mapSupabaseAuthError(const AuthException('Network request failed')),
      AuthErrorCode.network,
    );
    expect(
      mapSupabaseAuthError(const AuthException('something unexpected')),
      AuthErrorCode.generic,
    );
  });
}
