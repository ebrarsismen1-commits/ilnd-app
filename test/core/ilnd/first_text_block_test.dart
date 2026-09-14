import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/ilnd/ilnd_service.dart';

// Güvenlik denetimi L-5: model çıktısı yapı olarak güvenilir sayılmaz.
void main() {
  test('ilk metin bloğunu döner', () {
    expect(
      firstTextBlock({
        'content': [
          {'type': 'text', 'text': 'merhaba'},
          {'type': 'text', 'text': 'ikinci'},
        ],
      }),
      'merhaba',
    );
  });

  test('metin olmayan bloklar atlanır', () {
    expect(
      firstTextBlock({
        'content': [
          {'type': 'thinking', 'thinking': '...'},
          {'type': 'text', 'text': 'cevap'},
        ],
      }),
      'cevap',
    );
  });

  test('boş, eksik ya da bozuk içerikte fırlatmaz, null döner', () {
    expect(firstTextBlock({'content': <Object>[]}), isNull);
    expect(firstTextBlock({'stop_reason': 'refusal'}), isNull);
    expect(firstTextBlock({'content': 'metin'}), isNull);
    expect(
      firstTextBlock({
        'content': [
          {'type': 'text', 'text': 42},
        ],
      }),
      isNull,
    );
    expect(firstTextBlock(null), isNull);
    expect(firstTextBlock(['liste']), isNull);
  });
}
