import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/widgets/island_artwork.dart';
import 'package:ilnd_app/features/adan/adan_model.dart';
import 'package:ilnd_app/features/adan/island_scene.dart';

void main() {
  final all = kIslandItems.map((item) => item.id).toSet();
  final states = <String, IslandState>{
    'beginning': const IslandState(),
    'growing': const IslandState(earned: {'lantern', 'pine'}),
    'established': IslandState(earned: all),
    'quiet': IslandState(earned: all, quietDays: 40),
    'night': IslandState(earned: all),
  };
  for (final entry in states.entries) {
    testWidgets('${entry.key}: earned objects and responsive scene', (
      tester,
    ) async {
      for (final width in [280.0, 390.0, 900.0]) {
        final boundaryKey = GlobalKey();
        await tester.binding.setSurfaceSize(Size(width, 480));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 480),
                textScaler: TextScaler.linear(3),
              ),
              child: Center(
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: SizedBox(
                    width: width,
                    height: 400,
                    child: IslandScene(
                      state: entry.value,
                      p: entry.key == 'night'
                          ? AppPalette.dark
                          : AppPalette.light,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          final context = tester.element(find.byType(IslandScene));
          await precacheImage(
            ResizeImage(
              const AssetImage(IslandArtwork.terrainAsset),
              width: 1536,
            ),
            context,
          );
          for (final asset in IslandArtwork.assets) {
            await precacheImage(
              ResizeImage(AssetImage(asset), width: 768),
              context,
            );
          }
        });
        await tester.pump();
        expect(tester.takeException(), isNull);
        for (final item in kIslandItems) {
          expect(
            find.byKey(ValueKey('island-earned-${item.id}')),
            entry.value.has(item.id) ? findsOneWidget : findsNothing,
          );
        }
        expect(find.byType(Image), findsNWidgets(1 + entry.value.earnedCount));
        if (Platform.environment['ILND_SCENE_PREVIEW'] case final String dir
            when width == 390) {
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final png = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File(
              '$dir/${entry.key}.png',
            ).writeAsBytes(png.buffer.asUint8List());
            image.dispose();
          });
        }
      }
    });
  }
  testWidgets('quiet transition retains every object and changes only water', (
    tester,
  ) async {
    Future<void> pump(int days) => tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 390,
          height: 400,
          child: IslandScene(
            state: IslandState(earned: all, quietDays: days),
            p: AppPalette.light,
          ),
        ),
      ),
    );
    await pump(0);
    final before = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<IslandWaterPainter>()
        .toList();
    final elements = {
      for (final id in all)
        id: tester.element(find.byKey(ValueKey('island-earned-$id'))),
    };
    await pump(10);
    final after = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<IslandWaterPainter>()
        .toList();
    for (var i = 0; i < after.length; i++) {
      expect(after[i].shouldRepaint(before[i]), true);
    }
    for (final id in all) {
      expect(
        tester.element(find.byKey(ValueKey('island-earned-$id'))),
        same(elements[id]),
      );
    }
  });
}
