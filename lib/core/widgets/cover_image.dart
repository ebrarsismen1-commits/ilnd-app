import 'package:flutter/material.dart';
import 'package:ilnd_app/core/widgets/editorial_gradient.dart';

/// Kapak görseli: gerçek web fotoğrafını yükler, yüklenemezse (internet yok,
/// 404, demo) editoryal degradeye düşer. Yani asla kırık görünmez.
class CoverImage extends StatelessWidget {
  const CoverImage({super.key, required this.imageUrl, required this.palette});

  final String? imageUrl;
  final int palette;

  @override
  Widget build(BuildContext context) {
    final fallback = EditorialGradient(palette: palette);
    final url = imageUrl;
    if (url == null || url.isEmpty) return fallback;

    return Image.network(
      url,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : fallback,
      errorBuilder: (context, error, stack) => fallback,
      frameBuilder: (context, child, frame, wasSyncLoaded) {
        if (wasSyncLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
          child: child,
        );
      },
    );
  }
}
