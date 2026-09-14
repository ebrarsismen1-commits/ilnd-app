import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/repositories/events_repository.dart';
import 'package:ilnd_app/core/repositories/explore_repository.dart';
import 'package:ilnd_app/features/adan/adan_repository.dart';
import 'package:ilnd_app/features/adan/adan_screen.dart';
import 'package:ilnd_app/features/explore/explore_screen.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/profile/profile_provider.dart';
import 'package:ilnd_app/features/profile/profile_screen.dart';
import 'package:ilnd_app/features/topluluk/topluluk_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  Widget app(Widget child) => MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );

  Future<void> settleEntrance(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 800));
  }

  testWidgets('community loading is not mistaken for empty', (tester) async {
    final gate = Completer<List<CommunityEvent>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          upcomingEventsProvider.overrideWith((_) => gate.future.asStream()),
        ],
        child: app(const TopulukScreen()),
      ),
    );
    await tester.pump();
    await settleEntrance(tester);
    final l10n = lookupAppLocalizations(const Locale('tr'));
    expect(find.text(l10n.stateLoading), findsOneWidget);
    expect(find.text(l10n.topulukComingTitle), findsNothing);
  });

  testWidgets('community error has retry and no empty copy', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          upcomingEventsProvider.overrideWith(
            (_) => Stream.error(StateError('private')),
          ),
        ],
        child: app(const TopulukScreen()),
      ),
    );
    await tester.pump();
    await settleEntrance(tester);
    final l10n = lookupAppLocalizations(const Locale('tr'));
    expect(find.text(l10n.stateError), findsOneWidget);
    expect(find.text(l10n.stateRetry), findsOneWidget);
    expect(find.text('private'), findsNothing);
    expect(find.text(l10n.topulukComingTitle), findsNothing);
  });

  testWidgets('profile stats error does not show low-data copy', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          profileStatsProvider.overrideWith(
            (_) async => throw StateError('denied'),
          ),
        ],
        child: app(const ProfileScreen()),
      ),
    );
    await tester.pump();
    await settleEntrance(tester);
    final l10n = lookupAppLocalizations(const Locale('tr'));
    expect(find.text(l10n.stateError), findsOneWidget);
    expect(find.text(l10n.profileWeekEmpty), findsNothing);
    expect(find.text('denied'), findsNothing);
  });

  testWidgets('island error does not render default empty island', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          islandStateProvider.overrideWith(
            (_) => Stream.error(StateError('offline')),
          ),
          syncIslandProvider.overrideWithValue(() async {}),
        ],
        child: app(const AdanScreen()),
      ),
    );
    await tester.pump();
    await settleEntrance(tester);
    final l10n = lookupAppLocalizations(const Locale('tr'));
    expect(find.text(l10n.stateError), findsOneWidget);
    expect(find.text(l10n.adanLowData), findsNothing);
    expect(find.text('offline'), findsNothing);
  });

  testWidgets('explore backend error keeps fallback and exposes retry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          articlesProvider.overrideWith(
            (_) => Stream.error(StateError('timeout')),
          ),
        ],
        child: app(const ExploreScreen()),
      ),
    );
    await tester.pump();
    await settleEntrance(tester);
    final l10n = lookupAppLocalizations(const Locale('tr'));
    expect(find.text(l10n.stateError), findsOneWidget);
    expect(find.text(l10n.stateRetry), findsOneWidget);
    expect(find.text('timeout'), findsNothing);
    expect(find.text(l10n.exploreRitualsLabel), findsOneWidget);
  });
}
