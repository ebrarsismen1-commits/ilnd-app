import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// web/index.html'de senkron (async/defer'siz) harici script yasak:
/// `<head>` içindeki böyle bir script, dosya inene kadar HTML parse'ını
/// durdurur — dış sunucu yavaşsa/erişilemezse uygulama hiç başlamaz ve
/// kullanıcı splash'ta takılı kalır (yaşandı: GitHub'dan çekilen corbado
/// passkeys bundle'ı, üstelik uygulama passkey kullanmıyordu).
void main() {
  test('index.html render-bloklayan harici script içermez', () {
    final html = File('web/index.html').readAsStringSync();

    expect(
      html.contains('corbado'),
      isFalse,
      reason: 'Kullanılmayan passkeys bundle\'ı kaldırıldı — geri gelmemeli.',
    );

    final externalScripts = RegExp(
      '<script[^>]*src="https?://[^>]*>',
    ).allMatches(html);
    for (final m in externalScripts) {
      final tag = m.group(0)!;
      expect(
        tag.contains('async') || tag.contains('defer'),
        isTrue,
        reason:
            'Harici script async/defer olmalı, render\'ı bloklamamalı: '
            '$tag',
      );
    }
  });
}
