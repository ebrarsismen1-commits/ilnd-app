import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/ilnd/image_media_type.dart';

Uint8List _bytes(List<int> prefix) =>
    Uint8List.fromList([...prefix, ...List.filled(16, 0)]);

void main() {
  group('detectImageMediaType', () {
    test('JPEG imzasını tanır', () {
      expect(detectImageMediaType(_bytes([0xFF, 0xD8, 0xFF])), 'image/jpeg');
    });

    test('PNG imzasını tanır', () {
      expect(
        detectImageMediaType(_bytes([0x89, 0x50, 0x4E, 0x47])),
        'image/png',
      );
    });

    test('GIF imzasını tanır', () {
      expect(detectImageMediaType(_bytes('GIF8'.codeUnits)), 'image/gif');
    });

    test('WebP imzasını tanır', () {
      final webp = Uint8List.fromList([
        ...'RIFF'.codeUnits,
        0,
        0,
        0,
        0,
        ...'WEBP'.codeUnits,
        ...List.filled(8, 0),
      ]);
      expect(detectImageMediaType(webp), 'image/webp');
    });

    test('bilinmeyen biçimde null döner', () {
      expect(detectImageMediaType(_bytes([0x00, 0x01, 0x02, 0x03])), isNull);
    });

    test('çok kısa veride null döner', () {
      expect(detectImageMediaType(Uint8List.fromList([0xFF, 0xD8])), isNull);
    });
  });
}
