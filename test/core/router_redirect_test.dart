import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/features/onboarding/profile_sync.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

void main() {
  final user = User(
    id: 'u1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
  );

  String? redirect({
    AuthState? authState,
    ProfileHydrationStatus hydration = ProfileHydrationStatus.done,
    bool onboardingDone = true,
    bool firstEntryDone = true,
    bool linkFailed = false,
    required String location,
  }) => resolveRedirect(
    authState: authState ?? AuthAuthenticated(user),
    hydration: hydration,
    onboardingDone: onboardingDone,
    firstEntryDone: firstEntryDone,
    linkFailed: linkFailed,
    location: location,
  );

  test('hidratlama sürerken kullanıcı splash\'e çekilir', () {
    expect(
      redirect(hydration: ProfileHydrationStatus.syncing, location: routeHome),
      routeSplash,
    );
    expect(
      redirect(
        hydration: ProfileHydrationStatus.syncing,
        location: routeSplash,
      ),
      isNull,
    );
  });

  test('hidratlama bitince splash\'teki kullanıcı home\'a itilir — '
      'sonsuz splash bug\'ı (yaşandı: web/telefon)', () {
    expect(redirect(location: routeSplash), routeHome);
  });

  test('onboarding bitmemişse splash\'ten welcome\'a', () {
    expect(
      redirect(onboardingDone: false, location: routeSplash),
      routeWelcome,
    );
  });

  test('ilk giriş yapılmamışsa splash\'ten first-entry\'ye', () {
    expect(
      redirect(firstEntryDone: false, location: routeSplash),
      routeFirstEntry,
    );
  });

  test('kimliksiz kullanıcı splash\'te bırakılmaz', () {
    expect(
      redirect(authState: const AuthUnauthenticated(), location: routeSplash),
      routeLogin,
    );
    expect(
      redirect(
        authState: const AuthUnauthenticated(),
        onboardingDone: false,
        location: routeSplash,
      ),
      routeWelcome,
    );
  });

  test('normal gezinme bozulmadı: home\'daki kullanıcıya dokunulmaz', () {
    expect(redirect(location: routeHome), isNull);
    expect(redirect(location: routeChat), isNull);
  });

  test('auth/onboarding rotasında takılan authenticated kullanıcı → home', () {
    expect(redirect(location: routeLogin), routeHome);
    expect(redirect(location: routeWelcome), routeHome);
  });

  test('şifre kurtarma: kullanıcı yeni-şifre ekranına kilitlenir', () {
    // Sıfırlama linkinden gelen kullanıcı, yeni şifre belirlemeden
    // uygulamada gezinememeli — nereye giderse gitsin yeni-şifreye döner.
    expect(
      redirect(authState: AuthPasswordRecovery(user), location: routeHome),
      routeNewPassword,
    );
    expect(
      redirect(authState: AuthPasswordRecovery(user), location: routeLogin),
      routeNewPassword,
    );
    expect(
      redirect(
        authState: AuthPasswordRecovery(user),
        location: routeNewPassword,
      ),
      isNull,
    );
  });

  test('yasal sayfalar her durumda erişilebilir', () {
    expect(
      redirect(
        authState: const AuthUnauthenticated(),
        onboardingDone: false,
        location: routePrivacyPolicy,
      ),
      isNull,
    );
  });

  test('çözülemeyen e-posta linki: onboarding duvarı değil giriş ekranı', () {
    // Gerçek olay: süresi dolmuş sıfırlama linki
    // /?error=access_denied&error_code=otp_expired ile dönüyor. Tarayıcı
    // yeniyse onboardingDone=false oluyordu ve kullanıcı /onboarding/welcome'a
    // düşüyordu: ne hatayı görebiliyor ne de "şifremi unuttum"a ulaşabiliyordu.
    expect(
      redirect(
        authState: const AuthUnauthenticated(),
        onboardingDone: false,
        linkFailed: true,
        location: routeHome,
      ),
      routeLogin,
    );
    // Giriş ekranına varınca orada kalır — toast gösterilebilsin.
    expect(
      redirect(
        authState: const AuthUnauthenticated(),
        onboardingDone: false,
        linkFailed: true,
        location: routeLogin,
      ),
      isNull,
    );
    // Link hatası yokken davranış değişmez: onboarding duvarı durur.
    expect(
      redirect(
        authState: const AuthUnauthenticated(),
        onboardingDone: false,
        location: routeHome,
      ),
      routeWelcome,
    );
  });
}
