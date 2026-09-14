import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';

/// Shared, static illustration. The caller supplies server-earned object IDs.
/// Fire is scenery; it never implies an earned lantern or oven.
class IslandArtwork extends StatelessWidget {
  const IslandArtwork({
    super.key,
    this.p = AppPalette.light,
    this.earned = const {},
    this.waterDepth = 0,
    this.contentPadding = EdgeInsets.zero,
  });

  final AppPalette p;
  final Set<String> earned;
  final int waterDepth;
  final EdgeInsets contentPadding;

  static const terrainAsset = 'assets/island/terrain-v2.webp';
  static const objectsAsset = 'assets/island/objects-v2.webp';
  static const assets = [terrainAsset, objectsAsset];

  // One shared 1536×1024 design space, including each sprite's transparent cell.
  // Back-to-front order is stable even when earlier items are still locked.
  static const placements = <String, (int, Rect)>{
    'moonlight': (4, Rect.fromLTWH(790, 150, 170, 170)),
    'pine': (1, Rect.fromLTWH(440, 100, 270, 270)),
    'windrose': (3, Rect.fromLTWH(980, 240, 190, 190)),
    'oven': (2, Rect.fromLTWH(1050, 435, 220, 220)),
    'lantern': (0, Rect.fromLTWH(410, 460, 145, 145)),
    'meetingStone': (5, Rect.fromLTWH(640, 610, 215, 215)),
  };

  // Botanical twilight: preserve alpha and texture, without a black overlay.
  static const twilight = ColorFilter.matrix([
    .38,
    .08,
    .02,
    0,
    0,
    .04,
    .48,
    .04,
    0,
    2,
    .04,
    .10,
    .42,
    0,
    4,
    0,
    0,
    0,
    1,
    0,
  ]);

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: IslandWaterPainter(p: p, depth: waterDepth),
          ),
          Padding(
            padding: contentPadding,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = math.min(
                  constraints.maxWidth * .96,
                  constraints.maxHeight * 1.5,
                );
                // Two bounded decode sizes shared by previews and detail screens.
                final physicalWidth =
                    width * MediaQuery.devicePixelRatioOf(context);
                final decodeWidth = physicalWidth <= 768 ? 768 : 1536;
                return Center(
                  child: SizedBox(
                    width: width,
                    height: width / 1.5,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          terrainAsset,
                          cacheWidth: decodeWidth,
                          fit: BoxFit.contain,
                          frameBuilder: (context, child, frame, synchronous) =>
                              p.isDark
                              ? ColorFiltered(
                                  colorFilter: twilight,
                                  child: child,
                                )
                              : child,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                        for (final entry in placements.entries)
                          if (earned.contains(entry.key))
                            Positioned.fromRect(
                              key: ValueKey('island-earned-${entry.key}'),
                              rect: Rect.fromLTWH(
                                entry.value.$2.left * width / 1536,
                                entry.value.$2.top * width / 1536,
                                entry.value.$2.width * width / 1536,
                                entry.value.$2.height * width / 1536,
                              ),
                              child: _AtlasCell(
                                index: entry.value.$1,
                                dark: p.isDark && entry.key != 'moonlight',
                              ),
                            ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

/// Each cell uses the same ImageCache entry. Cropping happens at paint time;
/// no per-object image decoding or offscreen snapshots are needed.
class _AtlasCell extends StatelessWidget {
  const _AtlasCell({required this.index, required this.dark});
  final int index;
  final bool dark;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final side = constraints.maxWidth;
      Widget image = Image.asset(
        IslandArtwork.objectsAsset,
        cacheWidth: 768,
        width: side * 3,
        height: side * 2,
        fit: BoxFit.fill,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
      if (dark) {
        image = ColorFiltered(
          colorFilter: IslandArtwork.twilight,
          child: image,
        );
      }
      return ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          maxWidth: side * 3,
          maxHeight: side * 2,
          child: Transform.translate(
            offset: Offset(-(index % 3) * side, -(index ~/ 3) * side),
            child: image,
          ),
        ),
      );
    },
  );
}

/// Quiet days change only this layer. The island and all earned items remain.
class IslandWaterPainter extends CustomPainter {
  const IslandWaterPainter({required this.p, required this.depth});
  final AppPalette p;
  final int depth;

  @override
  void paint(Canvas canvas, Size size) {
    final sea = Color.lerp(p.sea, p.water, switch (depth) {
      0 => .04,
      1 => .12,
      _ => .20,
    })!;
    canvas.drawRect(Offset.zero & size, Paint()..color = sea);
    final paint = Paint()
      ..color = p.base.withValues(alpha: p.isDark ? .28 : .40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 6; i++) {
      final y = size.height * (.12 + i * .16);
      canvas.drawPath(
        Path()
          ..moveTo(size.width * .03, y)
          ..cubicTo(
            size.width * .18,
            y - 5,
            size.width * .24,
            y + 5,
            size.width * .34,
            y,
          ),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(size.width * .72, y + 8)
          ..quadraticBezierTo(size.width * .86, y, size.width * .96, y + 8),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(IslandWaterPainter oldDelegate) =>
      oldDelegate.p != p || oldDelegate.depth != depth;
}
