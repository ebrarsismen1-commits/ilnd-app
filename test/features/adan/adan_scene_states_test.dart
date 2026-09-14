import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/features/adan/adan_model.dart';
import 'package:ilnd_app/features/adan/adan_repository.dart';
import 'package:ilnd_app/features/adan/adan_screen.dart';
import 'package:ilnd_app/features/adan/island_scene.dart';
import 'package:ilnd_app/core/widgets/island_artwork.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    await (FontLoader(
      "MaterialIcons",
    )..addFont(rootBundle.load("fonts/MaterialIcons-Regular.otf"))).load();
    for (final entry in {
      'DMSans': 'DMSans-Regular',
      'Lora': 'Lora-Regular',
      'DMMono': 'DMMono-Medium',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load('assets/fonts/${entry.value}.ttf'))).load();
    }
  });
  for (final locale in ['tr', 'en']) {
    for (final mode in ['loading', 'empty', 'data', 'error']) {
      testWidgets('island $locale $mode at narrow 3x and normal size', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({'user_name': 'Test'});
        final prefs = await SharedPreferences.getInstance();
        final l10n = lookupAppLocalizations(Locale(locale));
        for (final width in [280.0, 390.0]) {
          await tester.binding.setSurfaceSize(Size(width, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final key = GlobalKey();
          final gate = Completer<IslandState>();
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [
                sharedPreferencesProvider.overrideWithValue(prefs),
                syncIslandProvider.overrideWithValue(() async {}),
                islandStateProvider.overrideWith(
                  (_) => switch (mode) {
                    'loading' => gate.future.asStream(),
                    'error' => Stream.error(
                      StateError('private permission-denied'),
                    ),
                    'data' => Stream.value(
                      IslandState(
                        earned: kIslandItems.map((i) => i.id).toSet(),
                        quietDays: 8,
                      ),
                    ),
                    _ => Stream.value(const IslandState()),
                  },
                ),
              ],
              child: MaterialApp(
                theme: AppTheme.light,
                locale: Locale(locale),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(width == 280 ? 3 : 1),
                  ),
                  child: child!,
                ),
                home: RepaintBoundary(key: key, child: const AdanScreen()),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
          expect(
            find.textContaining('private permission-denied'),
            findsNothing,
          );
          if (mode == 'loading' || mode == 'error') {
            expect(find.byType(IslandScene), findsNothing);
            expect(find.text(l10n.adanLowData), findsNothing);
            expect(find.text(l10n.adanItemsTitle), findsNothing);
            expect(
              find.text(
                mode == 'loading' ? l10n.stateLoading : l10n.stateError,
              ),
              findsOneWidget,
            );
          } else {
            expect(find.byType(IslandScene), findsOneWidget);
            expect(find.text(l10n.stateError), findsNothing);
            expect(find.text(l10n.stateLoading), findsNothing);
            await tester.scrollUntilVisible(
              find.text(
                mode == "empty" ? l10n.adanLowData : l10n.adanContext(6),
              ),
              100,
              scrollable: find.byType(Scrollable).first,
            );
            expect(
              find.text(
                mode == 'empty' ? l10n.adanLowData : l10n.adanContext(6),
              ),
              findsOneWidget,
            );
          }
          await tester.pump(const Duration(seconds: 1));
          if (mode == 'data' && width == 390 && locale == 'tr') {
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .jumpTo(0);
            await tester.pump(const Duration(seconds: 1));
            await tester.pump(const Duration(seconds: 1));
            if (Platform.environment['ILND_SCENE_PREVIEW']
                case final String dir) {
              await tester.runAsync(() async {
                final context = tester.element(find.byType(IslandScene));
                for (final asset in IslandArtwork.assets) {
                  await precacheImage(
                    ResizeImage(AssetImage(asset), width: 768),
                    context,
                  );
                }
              });
              await tester.pump();
              await tester.runAsync(() async {
                final boundary =
                    key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final image = await boundary.toImage(pixelRatio: 2);
                final png = (await image.toByteData(
                  format: ui.ImageByteFormat.png,
                ))!;
                await File(
                  '$dir/screen.png',
                ).writeAsBytes(png.buffer.asUint8List());
                image.dispose();
              });
            }
          }
          await tester.drag(find.byType(ListView), const Offset(0, -1200));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
