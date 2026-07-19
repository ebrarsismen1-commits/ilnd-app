import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/ilnd/ilnd_service.dart';
import 'package:ilnd_app/core/repositories/profile_repository.dart';
import 'package:ilnd_app/core/repositories/referral_repository.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/onboarding/screens/first_entry_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// İlk-giriş çıkış akışı: seçimde yığın home < vibe card < sohbet olmalı —
/// sohbet kapanınca kullanıcıyı İLK vibe card'ı karşılar (Faz 1C, "ilk
/// paylaşılabilir an"). Atlamada da kart gelir: home < vibe card.
class _FakeIlndService extends IlndService {
  const _FakeIlndService();

  @override
  Future<List<String>> suggestNeeds({
    required IlndMemory memory,
    required AppLocalizations l10n,
  }) async => const ['daha iyi uyku'];
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<GoRouter> pumpFirstEntry(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final router = GoRouter(
      initialLocation: routeFirstEntry,
      routes: [
        GoRoute(
          path: routeFirstEntry,
          builder: (_, _) => const FirstEntryScreen(),
        ),
        GoRoute(
          path: routeHome,
          builder: (_, _) => const Scaffold(body: Text('STUB_HOME')),
        ),
        GoRoute(
          path: routeVibeCard,
          builder: (_, _) => const Scaffold(body: Text('STUB_VIBE')),
        ),
        GoRoute(
          path: routeChat,
          builder: (_, _) => const Scaffold(body: Text('STUB_CHAT')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ilndMemoryProvider.overrideWith(
            (ref) => IlndMemoryNotifier(prefs, '', null),
          ),
          ilndServiceProvider.overrideWithValue(const _FakeIlndService()),
          // Auth'suz test: sunucu yazımları sessizce atlanır.
          profileRepositoryProvider.overrideWithValue(null),
          referralRepositoryProvider.overrideWithValue(null),
        ],
        child: MaterialApp.router(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    return router;
  }

  testWidgets('ihtiyaç seçimi: sohbet üstte, altında vibe card, tabanda home', (
    tester,
  ) async {
    final router = await pumpFirstEntry(tester);

    await tester.tap(find.text('daha iyi uyku'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('STUB_CHAT'), findsOneWidget);

    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('STUB_VIBE'), findsOneWidget);

    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('STUB_HOME'), findsOneWidget);
  });

  testWidgets('atlansa bile ilk vibe card gösterilir', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('tr'));
    final router = await pumpFirstEntry(tester);

    await tester.tap(find.text(l10n.firstEntrySkip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('STUB_VIBE'), findsOneWidget);

    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('STUB_HOME'), findsOneWidget);
  });
}
