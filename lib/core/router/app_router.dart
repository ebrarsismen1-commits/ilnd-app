import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/demo/demo_config.dart';
import 'package:ilnd_app/core/shell/app_shell.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/features/auth/login_screen.dart';
import 'package:ilnd_app/features/auth/register_screen.dart';
import 'package:ilnd_app/features/chat/chat_screen.dart';
import 'package:ilnd_app/features/explore/explore_screen.dart';
import 'package:ilnd_app/features/home/home_screen.dart';
import 'package:ilnd_app/features/legal/legal_screen.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/onboarding/screens/first_entry_screen.dart';
import 'package:ilnd_app/features/onboarding/screens/quick_setup_screen.dart';
import 'package:ilnd_app/features/onboarding/screens/welcome_screen.dart';
import 'package:ilnd_app/features/ekle/yemek_ekle_screen.dart';
import 'package:ilnd_app/features/splash/splash_screen.dart';
import 'package:ilnd_app/features/profile/profile_screen.dart';
import 'package:ilnd_app/features/referral/referral_screen.dart';
import 'package:ilnd_app/features/takip/takip_screen.dart';
import 'package:ilnd_app/features/vibe_card/vibe_card_screen.dart';

const routeSplash = '/splash';
const routeWelcome = '/onboarding/welcome';
const routeQuickSetup = '/onboarding/quick-setup';
const routeFirstEntry = '/onboarding/first-entry';
const routeLogin = '/login';
const routeRegister = '/register';
const routeHome = '/home';
const routeChat = '/chat';
const routeExplore = '/explore';
const routeJournal = '/journal';
const routeTakip = '/takip';
const routeProfile = '/profile';
const routeYemekEkle = '/yemek-ekle';
const routeVibeCard = '/vibe-card';
const routeReferral = '/referral';
const routePrivacyPolicy = '/legal/privacy';
const routeTermsOfService = '/legal/terms';

// ─── Auth-aware router notifier ───────────────────────────────────────────────

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authNotifierProvider,
      (prev, next) => notifyListeners(),
    );
    _ref.listen<bool>(
      onboardingDoneProvider,
      (prev, next) => notifyListeners(),
    );
    _ref.listen<bool>(
      firstEntryDoneProvider,
      (prev, next) => notifyListeners(),
    );
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    // Demo modu: auth/onboarding duvarı yok — doğrudan dolu uygulamaya in.
    if (kDemoMode) return null;

    final authState = _ref.read(authNotifierProvider);
    final onboardingDone = _ref.read(onboardingDoneProvider);
    final firstEntryDone = _ref.read(firstEntryDoneProvider);
    final location = state.matchedLocation;

    // Gizlilik Politikası / Kullanım Şartları her zaman erişilebilir olmalı —
    // App Store/Play Store gereksinimi, kayıt formundan (henüz auth yok) ya
    // da ayarlardan açılabilir. Auth/onboarding durumundan bağımsız.
    if (location == routePrivacyPolicy || location == routeTermsOfService) {
      return null;
    }

    // Still resolving — show splash screen.
    if (authState is AuthInitial) {
      return location == routeSplash ? null : routeSplash;
    }

    final isAuthenticated = authState is AuthAuthenticated;
    final isOnAuthRoute = location == routeLogin || location == routeRegister;
    final isOnboarding = location.startsWith('/onboarding');

    // Not onboarded → always push through onboarding (name/goals) first.
    if (!onboardingDone) {
      if (isOnboarding) return null;
      return routeWelcome;
    }

    // Onboarded but not authenticated → login (unless already there).
    if (!isAuthenticated) {
      if (isOnAuthRoute) return null;
      return routeLogin;
    }

    // Authenticated but hasn't written/skipped the first journal entry yet —
    // force the folded "first value" step before letting them reach home.
    if (!firstEntryDone) {
      if (location == routeFirstEntry) return null;
      return routeFirstEntry;
    }

    // Authenticated, first entry done, but stuck on an auth/onboarding route → home.
    if (isOnAuthRoute || location == routeFirstEntry) {
      return routeHome;
    }

    return null;
  }
}

// ─── Router provider ──────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    refreshListenable: notifier,
    redirect: notifier.redirect,
    initialLocation: routeHome,
    routes: [
      // ── Splash ────────────────────────────────────────────────────────────
      GoRoute(
        path: routeSplash,
        pageBuilder: (context, state) => _fade(state, const SplashScreen()),
      ),

      // ── Auth ──────────────────────────────────────────────────────────────
      GoRoute(
        path: routeLogin,
        pageBuilder: (context, state) => _fade(state, const LoginScreen()),
      ),
      GoRoute(
        path: routeRegister,
        pageBuilder: (context, state) => _fade(state, const RegisterScreen()),
      ),

      // ── ILND sohbet (tam ekran, shell dışı) ───────────────────────────────
      GoRoute(
        path: routeChat,
        pageBuilder: (context, state) => _fade(state, const ChatScreen()),
      ),
      GoRoute(
        path: routeYemekEkle,
        pageBuilder: (context, state) => _fade(state, const YemekEkleScreen()),
      ),
      GoRoute(
        path: routeReferral,
        pageBuilder: (context, state) => _fade(state, const ReferralScreen()),
      ),
      GoRoute(
        path: routeVibeCard,
        pageBuilder: (context, state) => _fade(state, const VibeCardScreen()),
      ),
      GoRoute(
        path: routePrivacyPolicy,
        pageBuilder: (context, state) =>
            _fade(state, LegalScreen.privacyPolicy),
      ),
      GoRoute(
        path: routeTermsOfService,
        pageBuilder: (context, state) =>
            _fade(state, LegalScreen.termsOfService),
      ),

      // ── Onboarding (no shell) ──────────────────────────────────────────────
      GoRoute(
        path: routeWelcome,
        pageBuilder: (context, state) => _fade(state, const WelcomeScreen()),
      ),
      GoRoute(
        path: routeQuickSetup,
        pageBuilder: (context, state) => _fade(state, const QuickSetupScreen()),
      ),
      GoRoute(
        path: routeFirstEntry,
        pageBuilder: (context, state) => _fade(state, const FirstEntryScreen()),
      ),

      // ── Main app shell: 4 branches ────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: routeHome,
                pageBuilder: (context, state) =>
                    _fade(state, const HomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: routeExplore,
                pageBuilder: (context, state) =>
                    _fade(state, const ExploreScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: routeTakip,
                pageBuilder: (context, state) =>
                    _fade(state, const TakipScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: routeProfile,
                pageBuilder: (context, state) =>
                    _fade(state, const ProfileScreen()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

CustomTransitionPage<void> _fade(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 200),
  );
}
