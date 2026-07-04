import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/ilnd/crisis_guard.dart';

void main() {
  group('CrisisGuard.matches', () {
    test('detects Turkish crisis phrases', () {
      expect(CrisisGuard.matches('artık yaşamak istemiyorum'), isTrue);
      expect(CrisisGuard.matches('İntihar etmeyi düşünüyorum'), isTrue);
      expect(CrisisGuard.matches('kendime zarar vermek istiyorum'), isTrue);
    });

    test('detects English crisis phrases', () {
      expect(CrisisGuard.matches('I want to die'), isTrue);
      expect(CrisisGuard.matches('thinking about suicide'), isTrue);
      expect(CrisisGuard.matches('I keep wanting to hurt myself'), isTrue);
      expect(CrisisGuard.matches('self-harm thoughts again'), isTrue);
    });

    test('does not fire on ordinary negative moods', () {
      expect(CrisisGuard.matches('bugün çok yorgunum ve mutsuzum'), isFalse);
      expect(CrisisGuard.matches('işte berbat bir gündü'), isFalse);
      expect(CrisisGuard.matches('I feel sad and tired today'), isFalse);
      expect(CrisisGuard.matches('bu diyet beni öldürüyor'), isFalse);
    });
  });
}
