import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/services/firebase_auth_bridge.dart';

// Güvenlik denetimi M-8: hesabı etkileyen çağrılar yalnız iki oturum aynı
// hesaba aitken yapılır.
void main() {
  bool match(String? fb, String? sb) =>
      FirebaseAuthBridge.sessionsMatch(firebaseUid: fb, supabaseUid: sb);

  test('aynı hesap eşleşir', () {
    expect(match('uid-A', 'uid-A'), isTrue);
  });

  test('önceki kullanıcının Firebase oturumu yeni Supabase hesabıyla '
      'eşleşmez', () {
    expect(match('uid-A', 'uid-B'), isFalse);
  });

  test('eksik oturum eşleşme sayılmaz', () {
    expect(match(null, 'uid-B'), isFalse);
    expect(match('uid-A', null), isFalse);
    expect(match(null, null), isFalse);
  });
}
