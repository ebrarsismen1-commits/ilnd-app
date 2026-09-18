import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';

void main() {
  AuthErrorCode map(String code) =>
      mapFirebaseAuthError(FirebaseAuthException(code: code));

  test('yanlış şifre / olmayan hesap / taşınmış şifresiz hesap', () {
    // Numaralandırma koruması açıkken üçü de invalid-credential döner;
    // metin şifre sıfırlamayı hatırlatır (ADR-0010).
    expect(map('invalid-credential'), AuthErrorCode.invalidCredentials);
    expect(map('wrong-password'), AuthErrorCode.invalidCredentials);
    expect(map('INVALID_LOGIN_CREDENTIALS'), AuthErrorCode.invalidCredentials);
    expect(map('user-not-found'), AuthErrorCode.userNotFound);
  });

  test('kayıt hataları', () {
    expect(map('email-already-in-use'), AuthErrorCode.emailInUse);
    expect(map('weak-password'), AuthErrorCode.weakPassword);
    expect(map('invalid-email'), AuthErrorCode.invalidEmail);
  });

  test('ağ ve bilinmeyen', () {
    expect(map('network-request-failed'), AuthErrorCode.network);
    expect(map('too-many-requests'), AuthErrorCode.generic);
    expect(map('something-unexpected'), AuthErrorCode.generic);
  });
}
