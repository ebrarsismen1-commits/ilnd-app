import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/shell/app_shell.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  const paths = ['/home', '/explore', '/topluluk', '/profile'];

  Future<GoRouter> mount(
    WidgetTester tester, {
    double scale = 1,
    double inset = 0,
    String language = 'tr',
  }) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: paths.first,
      routes: [
        GoRoute(
          path: '/chat',
          builder: (_, _) => const Scaffold(body: Text('CHAT')),
        ),
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => AppShell(navigationShell: shell),
          branches: [
            for (final path in paths)
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: path,
                    builder: (_, _) => Scaffold(body: Text(path)),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              padding: EdgeInsets.only(bottom: inset),
              viewPadding: EdgeInsets.only(bottom: inset),
            ),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('route selection and chat return stay synchronized', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final router = await mount(tester);
    final l = lookupAppLocalizations(const Locale('tr'));
    final labels = [l.navHome, l.navExplore, l.navCommunity, l.navYou];
    for (var i = 0; i < paths.length; i++) {
      await tester.tap(find.text(labels[i]));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, paths[i]);
      for (var j = 0; j < labels.length; j++) {
        expect(
          tester
              .getSemantics(find.bySemanticsLabel(labels[j]))
              .flagsCollection
              .isSelected,
          i == j ? Tristate.isTrue : Tristate.isFalse,
        );
      }
      await tester.tap(find.bySemanticsLabel(l.a11yOpenIlnd));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/chat');
      expect(find.byType(AppShell), findsNothing);
      router.pop();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, paths[i]);
    }
    router.go('/explore');
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.bySemanticsLabel(l.navExplore))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    handle.dispose();
  });

  for (final language in ['tr', 'en']) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('$language at ${scale}x: safe area and accessible targets', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await mount(tester, scale: scale, inset: 34, language: language);
        expect(tester.takeException(), isNull);
        final l = lookupAppLocalizations(Locale(language));
        for (final label in [
          l.navHome,
          l.navExplore,
          l.a11yOpenIlnd,
          l.navCommunity,
          l.navYou,
        ]) {
          final target = find.bySemanticsLabel(label);
          final size = tester.getSize(target);
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
          expect(tester.getBottomRight(target).dy, lessThanOrEqualTo(666));
          expect(
            tester
                .getSemantics(target)
                .getSemanticsData()
                .hasAction(SemanticsAction.tap),
            isTrue,
          );
        }
        final shell = tester.widget<Scaffold>(
          find
              .descendant(
                of: find.byType(AppShell),
                matching: find.byType(Scaffold),
              )
              .first,
        );
        expect(
          tester.getSize(find.byWidget(shell.bottomNavigationBar!)).height,
          closeTo(64 + (scale - 1) * 24 + 34, 1),
        );
        handle.dispose();
      });
    }
  }
}
