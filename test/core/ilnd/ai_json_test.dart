import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/ilnd/ai_json.dart';

void main() {
  group('extractJsonObject', () {
    test('çıplak JSON nesnesini aynen döndürür', () {
      const raw = '{"yemek_adi": "Mercimek Çorbası", "kalori": 180}';
      expect(extractJsonObject(raw), raw);
    });

    test('markdown çitli yanıttan JSON ayıklar', () {
      const raw = '```json\n{"secenekler": ["yeni tarif"]}\n```';
      expect(extractJsonObject(raw), '{"secenekler": ["yeni tarif"]}');
    });

    test('önü/arkası açıklamalı yanıttan JSON ayıklar', () {
      const raw = 'İşte analiz sonucu:\n{"kalori": 320}\nUmarım yardımcı olur!';
      expect(extractJsonObject(raw), '{"kalori": 320}');
    });

    test('iç içe nesnelerde en dış nesneyi döndürür', () {
      const raw = 'x {"a": {"b": 1}, "c": 2} y';
      expect(extractJsonObject(raw), '{"a": {"b": 1}, "c": 2}');
    });

    test('JSON yoksa null döner', () {
      expect(extractJsonObject('bugün hava çok güzel'), isNull);
      expect(extractJsonObject(''), isNull);
    });

    test('sadece açılış braces varsa null döner', () {
      expect(extractJsonObject('{"yarim": '), isNull);
    });
  });
}
