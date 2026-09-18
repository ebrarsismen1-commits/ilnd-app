import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Firebase Auth'un kayıt/giriş/çıkış davranışını taklit eden sahte.
/// Hesaplar bellekte; `createUser…` gerçek Firebase gibi hemen oturum açar.
class _Info implements fb_auth.UserInfo {
  _Info(this.providerId);
  @override
  final String providerId;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _User implements fb_auth.User {
  _User(this.uid, this.email, {this.emailVerified = false, String? provider})
    : providerData = [_Info(provider ?? 'password')];
  @override
  final String uid;
  @override
  final String? email;
  @override
  bool emailVerified;
  @override
  final List<fb_auth.UserInfo> providerData;
  String? password;
  String? displayName_;
  int verificationMails = 0;

  @override
  Future<void> sendEmailVerification([
    fb_auth.ActionCodeSettings? actionCodeSettings,
  ]) async => verificationMails++;

  @override
  Future<void> updateDisplayName(String? displayName) async =>
      displayName_ = displayName;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Cred implements fb_auth.UserCredential {
  _Cred(this.user);
  @override
  final fb_auth.User? user;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Auth implements fb_auth.FirebaseAuth {
  final accounts = <String, _User>{};
  final _changes = StreamController<fb_auth.User?>.broadcast(sync: true);
  _User? _current;
  int signOuts = 0;
  final resetMails = <String>[];

  void _set(_User? u) {
    _current = u;
    _changes.add(u);
  }

  @override
  fb_auth.User? get currentUser => _current;

  @override
  Stream<fb_auth.User?> userChanges() => _changes.stream;

  @override
  Stream<fb_auth.User?> authStateChanges() => _changes.stream;

  @override
  Future<fb_auth.UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (accounts.containsKey(email)) {
      throw fb_auth.FirebaseAuthException(code: 'email-already-in-use');
    }
    final u = _User('uid-${accounts.length + 1}', email)..password = password;
    accounts[email] = u;
    _set(u);
    return _Cred(u);
  }

  @override
  Future<fb_auth.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final u = accounts[email];
    if (u == null || u.password != password) {
      throw fb_auth.FirebaseAuthException(code: 'invalid-credential');
    }
    _set(u);
    return _Cred(u);
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    fb_auth.ActionCodeSettings? actionCodeSettings,
  }) async => resetMails.add(email);

  @override
  Future<void> signOut() async {
    signOuts++;
    _set(null);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth fake;
  late ProviderContainer c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fake = _Auth();
    debugFirebaseAuthOverride = fake;
    c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    c.listen(authNotifierProvider, (_, _) {});
  });

  tearDown(() => debugFirebaseAuthOverride = null);

  AuthState state() => c.read(authNotifierProvider);
  AuthNotifier notifier() => c.read(authNotifierProvider.notifier);

  test('oturum yokken başlangıç: kimliksiz', () {
    expect(state(), isA<AuthUnauthenticated>());
  });

  test('kayıt: onay maili gider, oturum kapanır, onay bekleniyor', () async {
    await notifier().signUp(' ela@x.com ', 'sifre123', ' Ela ');
    await pumpEventQueue();
    final u = fake.accounts['ela@x.com']!;
    expect(state(), isA<AuthConfirmEmailPending>());
    expect((state() as AuthConfirmEmailPending).email, 'ela@x.com');
    expect(u.verificationMails, 1);
    expect(u.displayName_, 'Ela');
    expect(fake.currentUser, isNull);
  });

  test('doğrulanmamış hesapla giriş: reddedilir, mail yeniden gider', () async {
    fake.accounts['a@x.com'] = _User('uid-a', 'a@x.com')..password = 'p';
    await notifier().signIn('a@x.com', 'p');
    await pumpEventQueue();
    expect(state(), isA<AuthError>());
    expect((state() as AuthError).code, AuthErrorCode.confirmEmail);
    expect(fake.accounts['a@x.com']!.verificationMails, 1);
    expect(fake.currentUser, isNull);
  });

  test('doğrulanmış hesapla giriş → current user; çıkış → kimliksiz', () async {
    fake.accounts['a@x.com'] = _User('uid-a', 'a@x.com', emailVerified: true)
      ..password = 'p';
    await notifier().signIn('a@x.com', 'p');
    await pumpEventQueue();
    expect(state(), isA<AuthAuthenticated>());
    expect((state() as AuthAuthenticated).user.id, 'uid-a');
    expect((state() as AuthAuthenticated).user.email, 'a@x.com');

    await notifier().signOut();
    await pumpEventQueue();
    expect(state(), isA<AuthUnauthenticated>());
    expect(fake.signOuts, 1);
  });

  test(
    'yanlış şifre → invalidCredentials (taşınmış şifresiz hesap da)',
    () async {
      fake.accounts['a@x.com'] = _User('uid-a', 'a@x.com', emailVerified: true);
      await notifier().signIn('a@x.com', 'herhangi');
      expect((state() as AuthError).code, AuthErrorCode.invalidCredentials);
    },
  );

  test('aynı e-postayla ikinci kayıt → emailInUse', () async {
    await notifier().signUp('a@x.com', 'p12345', 'A');
    await notifier().signUp('a@x.com', 'p12345', 'A');
    expect((state() as AuthError).code, AuthErrorCode.emailInUse);
  });

  test('Google/Apple hesabı e-posta doğrulaması beklemez', () async {
    fake._set(_User('uid-g', 'g@x.com', provider: 'google.com'));
    await pumpEventQueue();
    expect((state() as AuthAuthenticated).user.id, 'uid-g');
  });

  test(
    'uygulama yeniden açılışı: kayıtlı doğrulanmış oturum geri gelir',
    () async {
      final prefs = c.read(sharedPreferencesProvider);
      final restarted = _Auth()
        .._current = _User('uid-r', 'r@x.com', emailVerified: true);
      debugFirebaseAuthOverride = restarted;
      final c2 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c2.dispose);
      final s = c2.read(authNotifierProvider);
      expect(s, isA<AuthAuthenticated>());
      expect((s as AuthAuthenticated).user.id, 'uid-r');
    },
  );

  test('şifre sıfırlama maili Firebase üzerinden gider', () async {
    await notifier().resetPassword(' a@x.com ');
    expect(fake.resetMails, ['a@x.com']);
  });
}
