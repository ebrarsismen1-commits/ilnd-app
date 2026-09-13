import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/ilnd/ilnd_service.dart';

/// Akan sohbetin tek ayrıştırma noktası. Anthropic akışında metin taşıyan
/// yalnız `content_block_delta` olayları var; gerisi (ping, message_start,
/// event satırları) sessizce atlanmalı. Bozuk tek bir satırın akışı
/// öldürmesi, kullanıcı için yarım kalmış bir cümle demek.
void main() {
  String? delta(String line) => sseTextDelta(line);

  test('metin parçasını ayıklar', () {
    expect(
      delta(
        'data: {"type":"content_block_delta",'
        '"delta":{"type":"text_delta","text":"merhaba"}}',
      ),
      'merhaba',
    );
  });

  test('metin taşımayan olaylar atlanır', () {
    expect(delta('event: content_block_delta'), isNull);
    expect(delta('data: {"type":"message_start"}'), isNull);
    expect(delta('data: {"type":"ping"}'), isNull);
    expect(delta('data: [DONE]'), isNull);
    expect(delta(''), isNull);
    expect(
      delta(
        'data: {"type":"content_block_delta",'
        '"delta":{"type":"input_json_delta","partial_json":"{"}}',
      ),
      isNull,
      reason: 'Yalnız text_delta metin taşır',
    );
  });

  test('bozuk satır akışı öldürmez', () {
    expect(delta('data: {bu json değil'), isNull);
    expect(delta('data: null'), isNull);
    expect(delta('data: [1,2,3]'), isNull);
  });

  // Güvenlik denetimi M-1: yarım kalan akış tamamlanmış sayılmamalı.
  test('message_stop akışın düzgün bittiğini söyler', () {
    expect(sseIsMessageStop('data: {"type":"message_stop"}'), isTrue);
    expect(sseIsMessageStop('event: message_stop'), isFalse);
    expect(sseIsMessageStop('data: {"type":"message_delta"}'), isFalse);
    expect(sseIsMessageStop('data: {bozuk'), isFalse);
  });

  test('proxy ve Anthropic hata olayları tanınır', () {
    expect(
      sseIsError(
        'data: {"type":"error","error":{"type":"proxy_error",'
        '"message":"Upstream AI request failed"}}',
      ),
      isTrue,
    );
    expect(
      sseIsError('data: {"type":"error","error":{"type":"overloaded_error"}}'),
      isTrue,
    );
    expect(sseIsError('event: error'), isFalse);
    expect(sseIsError('data: {"type":"ping"}'), isFalse);
    expect(sseIsError('data: [DONE]'), isFalse);
  });

  test('boşluklar ve Türkçe karakterler korunur', () {
    expect(
      delta(
        'data: {"type":"content_block_delta",'
        '"delta":{"type":"text_delta","text":" ağır çünkü "}}',
      ),
      ' ağır çünkü ',
    );
  });
}
