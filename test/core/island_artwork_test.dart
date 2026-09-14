import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/widgets/island_artwork.dart';

void main() {
  testWidgets('bundled island layers render on a wide card', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: const SizedBox(
              width: 362,
              height: 271,
              child: IslandArtwork(),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      if (find
          .descendant(
            of: find.byType(IslandArtwork),
            matching: find.byType(CustomPaint),
          )
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
    expect(
      find.descendant(
        of: find.byType(IslandArtwork),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final pixels = (await image.toByteData())!;
      final colors = <int>{};
      for (var i = 0; i < pixels.lengthInBytes; i += 40) {
        colors.add(pixels.getUint32(i));
      }
      expect(
        colors.length,
        greaterThan(100),
        reason: 'Artwork must paint details, not blank color bands.',
      );
      if (Platform.environment['ILND_ARTWORK_PREVIEW'] case final String path) {
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File(path).writeAsBytes(png.buffer.asUint8List());
      }
      image.dispose();
    });
  });
}
