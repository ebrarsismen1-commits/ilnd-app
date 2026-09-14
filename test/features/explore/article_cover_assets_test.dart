import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/widgets/cover_image.dart';
import 'package:ilnd_app/features/explore/article_cover_assets.dart';
import 'package:ilnd_app/features/explore/article_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('every editorial article has a valid bundled cover', () async {
    final articles =
        jsonDecode(File('content/articles.json').readAsStringSync()) as List;
    expect(
      articleCoverAssets.keys.toSet(),
      articles.map((a) => a['id']).toSet(),
    );
    // A small number of editorial/object covers are intentionally reused to
    // break consecutive portrait repetition; uniqueness is not a product
    // requirement as long as the asset itself is valid.
    expect(articleCoverAssets.values.toSet().length, greaterThan(100));
    for (final path in articleCoverAssets.values) {
      expect(File(path).existsSync(), isTrue, reason: path);
      expect(File(path).lengthSync(), greaterThan(100), reason: path);
      final bytes = await rootBundle.load(path);
      expect(bytes.lengthInBytes, File(path).lengthSync(), reason: path);
      if (path.endsWith('.webp')) {
        expect(bytes.getUint32(0), 0x52494646, reason: 'WebP RIFF header: $path');
      }
      if (path.endsWith('.svg')) continue;
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        targetWidth: 64,
      );
      try {
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 64, reason: path);
        expect(frame.image.height, greaterThan(0), reason: path);
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
    }
  });

  Article article(String id, String? url) => Article(
    id: id,
    title: 'Cover',
    category: ArticleCategory.beslenme,
    readTime: '3',
    excerpt: '',
    body: const [],
    imageUrl: url,
  );

  test(
    'empty CMS covers use bundled art; explicit and unknown covers survive',
    () {
      final id = articleCoverAssets.keys.first;
      expect(article(id, null).coverImageUrl, articleCoverAssets[id]);
      expect(article(id, '').coverImageUrl, articleCoverAssets[id]);
      expect(
        article(id, 'https://example.com/new.webp').coverImageUrl,
        'https://example.com/new.webp',
      );
      expect(article('future-article', null).coverImageUrl, isNull);
    },
  );

  testWidgets('local cover uses asset loading instead of a network request', (
    tester,
  ) async {
    final path = articleCoverAssets.values.first;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 300,
          height: 180,
          child: CoverImage(imageUrl: path, palette: 0),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<AssetImage>());
    expect((image.image as AssetImage).assetName, path);
  });
}
