import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ilnd_app/features/ekle/food_analysis.dart';
import 'package:ilnd_app/features/ekle/food_analysis_l10n.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Analizin ağ dalı. Buradaki her satır ya para ya sessiz veri kaybı:
///   429 + free-weekly-limit → PAYWALL (ödeme anı)
///   429 + başka sebep       → nazik hata (kötüye kullanana paywall gösterilmez)
///   bozuk JSON / zaman aşımı → hata ekranı, "analiz ediliyor"da sıkışma yok
/// Bu dal widget'ın içindeyken hiç test edilemiyordu; food_analysis.dart'a
/// ayrıldıktan sonra hepsi deterministik olarak koşuyor.

const _proxy = 'https://example.test/anthropicProxy';

/// PNG imzalı geçerli bir 1x1 görsel — `detectImageMediaType` bunu tanır.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQ'
  'DwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// Anthropic'in yanıt zarfı: içerik bloklarının ilkinin metni.
String _envelope(String text) => jsonEncode({
  'content': [
    {'type': 'text', 'text': text},
  ],
});

const _validFood =
    '{"yemek_adi": "Mercimek Çorbası", "kalori": 180, "protein": 9.0, '
    '"karbonhidrat": 27.0, "yag": 4.5, "malzemeler": ["mercimek", "soğan"]}';

FoodAnalyzer _analyzer(MockClient client) => FoodAnalyzer(
  proxyUrl: _proxy,
  client: client,
  appCheck: () async => const {'X-Firebase-AppCheck': 'appcheck-token'},
);

/// Hiç çağrılmaması gereken istemci — çağrılırsa test düşer.
MockClient _neverCalled() =>
    MockClient((_) async => fail('ağ çağrısı yapılmamalıydı'));

Future<FoodAnalysis> _run(
  MockClient client, {
  Uint8List? bytes,
  Future<String?> Function()? idToken,
  bool turkish = true,
}) => _analyzer(client).analyse(
  photoBytes: bytes ?? Uint8List.fromList(_png),
  idToken: idToken ?? () async => 'id-token',
  turkish: turkish,
);

void main() {
  group('çağrıdan önceki korumalar', () {
    test('tanınmayan görsel biçiminde ağa hiç çıkılmaz', () async {
      final out = await _run(
        _neverCalled(),
        bytes: Uint8List.fromList(List.filled(64, 7)),
      );
      expect(
        out,
        isA<FoodAnalysisFailure>().having(
          (f) => f.code,
          'code',
          FoodAnalysisErrorCode.unsupportedImage,
        ),
      );
    });

    test('4MB üstü fotoğraf gönderilmez', () async {
      // Anthropic sınırı 5MB; picker'ın küçültmesi web'de garanti değil.
      final big = Uint8List(kMaxFoodPhotoBytes + 1)
        ..setRange(0, _png.length, _png);
      final out = await _run(_neverCalled(), bytes: big);
      expect(
        out,
        isA<FoodAnalysisFailure>().having(
          (f) => f.code,
          'code',
          FoodAnalysisErrorCode.photoTooLarge,
        ),
      );
    });

    test('kimlik jetonu yoksa çağrı yapılmaz', () async {
      final out = await _run(_neverCalled(), idToken: () async => null);
      expect(
        out,
        isA<FoodAnalysisFailure>().having(
          (f) => f.code,
          'code',
          FoodAnalysisErrorCode.failed,
        ),
      );
    });
  });

  group('429 — iki farklı anlam', () {
    test('free-weekly-limit paywall anıdır, hata değil', () async {
      final out = await _run(
        MockClient(
          (_) async => http.Response.bytes(
            utf8.encode('{"error":"limit","reason":"free-weekly-limit"}'),
            429,
          ),
        ),
      );
      expect(out, isA<FoodAnalysisFreeLimit>());
    });

    test('günlük tavan paywall DEĞİL, nazik hatadır', () async {
      final out = await _run(
        MockClient(
          (_) async => http.Response.bytes(
            utf8.encode('{"error":"limit","reason":"daily-tier-limit"}'),
            429,
          ),
        ),
      );
      expect(
        out,
        isA<FoodAnalysisFailure>().having(
          (f) => f.code,
          'code',
          FoodAnalysisErrorCode.failed,
        ),
        reason: 'kötüye kullanım tavanına takılana paywall gösterilmez',
      );
    });
  });

  group('yanıt işleme', () {
    test('geçerli JSON sonuca dönüşür', () async {
      final out = await _run(
        MockClient(
          (_) async =>
              http.Response.bytes(utf8.encode(_envelope(_validFood)), 200),
        ),
      );
      final result = (out as FoodAnalysisSuccess).result;
      expect(result.yemekAdi, 'Mercimek Çorbası');
      expect(result.kalori, 180);
      expect(result.protein, 9.0);
      expect(result.malzemeler, ['mercimek', 'soğan']);
    });

    test('markdown çitli yanıttan JSON ayıklanır', () async {
      // Assistant-prefill yasak olduğu için model yanıta çit/açıklama
      // ekleyebilir (CLAUDE.md kural #8).
      final out = await _run(
        MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              _envelope(
                'İşte analiz:\n```json\n$_validFood\n```\nAfiyet olsun!',
              ),
            ),
            200,
          ),
        ),
      );
      expect((out as FoodAnalysisSuccess).result.kalori, 180);
    });

    test('Türkçe karakterler UTF-8 olarak çözülür', () async {
      // `response.body` latin-1 varsayar; bodyBytes + utf8.decode şart.
      final out = await _run(
        MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              _envelope(
                _validFood.replaceFirst('Mercimek Çorbası', 'Şiş Köfte'),
              ),
            ),
            200,
          ),
        ),
      );
      expect((out as FoodAnalysisSuccess).result.yemekAdi, 'Şiş Köfte');
    });

    test('JSON içermeyen yanıt hataya düşer', () async {
      final out = await _run(
        MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(_envelope('bugün bir yemek göremedim')),
            200,
          ),
        ),
      );
      expect(
        out,
        isA<FoodAnalysisFailure>().having(
          (f) => f.code,
          'code',
          FoodAnalysisErrorCode.failed,
        ),
      );
    });

    test('eksik alanlı JSON patlatmaz, hataya düşer', () async {
      final out = await _run(
        MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(_envelope('{"yemek_adi": "Pilav"}')),
            200,
          ),
        ),
      );
      expect(
        out,
        isA<FoodAnalysisFailure>().having(
          (f) => f.code,
          'code',
          FoodAnalysisErrorCode.failed,
        ),
      );
    });

    test('200 dışı durum kodu kullanıcıya taşınır', () async {
      final out = await _run(
        // Gövde bayt olarak veriliyor: http.Response'un String kurucusu
        // latin-1 varsayar ve Türkçe karakterde kendisi patlar.
        MockClient(
          (_) async =>
              http.Response.bytes(utf8.encode('upstream patladı'), 503),
        ),
      );
      final failure = out as FoodAnalysisFailure;
      expect(failure.code, FoodAnalysisErrorCode.failedStatus);
      expect(failure.statusCode, 503);
    });
  });

  group('ağ hataları', () {
    test('bağlantı yoksa internet mesajına düşer', () async {
      final out = await _run(
        MockClient((_) async => throw const SocketException('ağ yok')),
      );
      expect(
        out,
        isA<FoodAnalysisFailure>().having(
          (f) => f.code,
          'code',
          FoodAnalysisErrorCode.noInternet,
        ),
      );
    });

    test('zaman aşımı sıkışmaya değil hataya dönüşür', () async {
      final out = await _run(
        MockClient((_) async => throw TimeoutException('çok uzun sürdü')),
      );
      expect(
        out,
        isA<FoodAnalysisFailure>().having(
          (f) => f.code,
          'code',
          FoodAnalysisErrorCode.failed,
        ),
      );
    });

    test('zaman aşımı süresi sınırsız değil', () {
      // Timeout kaldırılırsa ekran sonsuza dek "analiz ediliyor"da kalır.
      expect(kFoodAnalysisTimeout, const Duration(seconds: 60));
    });
  });

  group('istek gövdesi', () {
    test('proxy sözleşmesi ve prompt kuralları korunur', () async {
      late http.Request captured;
      await _run(
        MockClient((req) async {
          captured = req;
          return http.Response.bytes(utf8.encode(_envelope(_validFood)), 200);
        }),
      );

      expect(captured.url, Uri.parse(_proxy));
      expect(captured.headers['Authorization'], 'Bearer id-token');
      expect(captured.headers['X-Firebase-AppCheck'], 'appcheck-token');

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['tier'], 'deep', reason: 'görsel analizi Sonnet katmanı');
      expect(
        body['kind'],
        'food',
        reason: 'sunucudaki haftalık kota bu alandan düşer',
      );

      final messages = body['messages'] as List;
      expect(
        messages.every((m) => (m as Map)['role'] != 'assistant'),
        isTrue,
        reason: 'assistant-prefill Claude 4.6+ tarafından 400 ile reddedilir',
      );

      final content = (messages.first as Map)['content'] as List;
      final image = content.first as Map;
      expect(
        (image['source'] as Map)['media_type'],
        'image/png',
        reason: 'media_type görselin gerçek biçiminden gelmeli',
      );
    });

    test('dil kuralı yemek adının dilini belirler', () async {
      Future<String> promptFor({required bool turkish}) async {
        late http.Request captured;
        await _run(
          MockClient((req) async {
            captured = req;
            return http.Response.bytes(utf8.encode(_envelope(_validFood)), 200);
          }),
          turkish: turkish,
        );
        final body = jsonDecode(captured.body) as Map<String, dynamic>;
        final content =
            ((body['messages'] as List).first as Map)['content'] as List;
        return (content.last as Map)['text'] as String;
      }

      expect(await promptFor(turkish: true), contains('Türkçe'));
      expect(await promptFor(turkish: false), contains('İngilizce'));
    });
  });

  group('hata kodu çevirisi', () {
    final l10n = lookupAppLocalizations(const Locale('tr'));

    test('her kod kendi .arb metnine düşer', () {
      String msg(FoodAnalysisErrorCode code, {int? status}) =>
          FoodAnalysisFailure(code, statusCode: status).localized(l10n);

      expect(
        msg(FoodAnalysisErrorCode.unsupportedImage),
        l10n.yemekEkleUnsupportedImage,
      );
      expect(
        msg(FoodAnalysisErrorCode.photoTooLarge),
        l10n.yemekEklePhotoTooLarge,
      );
      expect(msg(FoodAnalysisErrorCode.failed), l10n.yemekEkleAnalysisFailed);
      expect(msg(FoodAnalysisErrorCode.noInternet), l10n.yemekEkleNoInternet);
      expect(
        msg(FoodAnalysisErrorCode.failedStatus, status: 503),
        contains('503'),
      );
    });

    test('kodların mesajları birbirinden ayırt edilebilir', () {
      // Hepsi aynı metne düşerse kullanıcı ne olduğunu anlayamaz.
      final messages = FoodAnalysisErrorCode.values
          .map((c) => FoodAnalysisFailure(c, statusCode: 500).localized(l10n))
          .toSet();
      expect(messages, hasLength(FoodAnalysisErrorCode.values.length));
    });
  });
}
