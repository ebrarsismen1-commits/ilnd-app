import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Güvenlik denetimi M-11: web uygulaması güvenlik başlıksız sunuluyordu.
/// Başka bir site uygulamayı iframe'e alıp kullanıcıya görünmez tıklatarak
/// "hesabı sil" onayı verdirebilirdi (clickjacking).
void main() {
  Map<String, String> headersFor(String source) {
    final config =
        jsonDecode(File('firebase.json').readAsStringSync())
            as Map<String, dynamic>;
    final blocks =
        (config['hosting'] as Map<String, dynamic>)['headers'] as List<dynamic>;
    final block = blocks.cast<Map<String, dynamic>>().firstWhere(
      (b) => b['source'] == source,
      orElse: () => fail('"$source" için başlık bloğu yok'),
    );
    return {
      for (final h in (block['headers'] as List).cast<Map<String, dynamic>>())
        (h['key'] as String).toLowerCase(): h['value'] as String,
    };
  }

  test('tüm yollar çerçevelenemez (clickjacking)', () {
    final h = headersFor('**');
    expect(h['content-security-policy'], contains("frame-ancestors 'none'"));
    expect(h['x-frame-options'], 'DENY');
  });

  test('MIME koklama ve yönlendiren sızıntısı kapalı', () {
    final h = headersFor('**');
    expect(h['x-content-type-options'], 'nosniff');
    expect(h['referrer-policy'], 'strict-origin-when-cross-origin');
  });

  test('yalnız yemek fotoğrafı için kamera; mikrofon ve konum kapalı', () {
    final policy = headersFor('**')['permissions-policy']!;
    expect(policy, contains('camera=(self)'));
    expect(policy, contains('microphone=()'));
    expect(policy, contains('geolocation=()'));
  });
}
