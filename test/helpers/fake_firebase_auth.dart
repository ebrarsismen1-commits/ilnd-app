import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:ilnd_app/features/auth/auth_provider.dart';

/// Oturumu olmayan, ağa hiç çıkmayan FirebaseAuth. AuthNotifier kurucusunda
/// FirebaseAuth'u okuyor; testte Firebase başlatılmadığı için bunu verin.
/// Kullanılmayan bir üye çağrılırsa test yüksek sesle patlar.
class FakeFirebaseAuth implements fb_auth.FirebaseAuth {
  @override
  fb_auth.User? get currentUser => null;

  @override
  Stream<fb_auth.User?> authStateChanges() => const Stream.empty();

  @override
  Stream<fb_auth.User?> userChanges() => const Stream.empty();

  @override
  Stream<fb_auth.User?> idTokenChanges() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeFirebaseAuth: ${invocation.memberName}');
}

/// setUpAll içinde çağırın.
void useFakeFirebaseAuth() => debugFirebaseAuthOverride = FakeFirebaseAuth();
