import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('memory is isolated per user id — no cross-account leak', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final u1 = IlndMemoryNotifier(prefs, '', 'user-1');
    await u1.setName('Ela');

    // Farklı hesapla giriş: yeni kullanıcı Ela'nın hafızasını GÖRMEMELİ.
    final u2 = IlndMemoryNotifier(prefs, '', 'user-2');
    expect(u2.state.name, isEmpty);

    // Ela geri gelirse hafızası yerinde.
    final u1b = IlndMemoryNotifier(prefs, '', 'user-1');
    expect(u1b.state.name, 'Ela');
  });

  test(
    'legacy single-key memory migrates to the first signed-in user',
    () async {
      SharedPreferences.setMockInitialValues({
        'ilnd_memory': jsonEncode(const IlndMemory(name: 'Ela').toJson()),
      });
      final prefs = await SharedPreferences.getInstance();

      final u1 = IlndMemoryNotifier(prefs, '', 'user-1');
      expect(u1.state.name, 'Ela'); // hafıza korunur
      expect(prefs.getString('ilnd_memory'), isNull); // global anahtar silinir
      expect(prefs.getString('ilnd_memory_user-1'), isNotNull);
    },
  );
}
