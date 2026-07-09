import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/ilnd/ilnd_character.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';

void main() {
  test('sistem prompt\'u yazım kurallarını içerir (tire yasağı dahil)', () {
    final prompt = IlndCharacter.systemPrompt(memory: const IlndMemory());

    // Kullanıcı şikayeti: AI durmadan tire kullanıyor ve yazım hatası
    // yapıyordu. Bu kurallar prompt'tan silinirse üslup geri bozulur.
    expect(prompt, contains('Yazım kuralların'));
    expect(prompt, contains('KULLANMAZSIN'));
    expect(prompt, contains('Kusursuz imla'));
  });

  test('dil kuralı ve görev prompt\'a işlenir', () {
    final prompt = IlndCharacter.systemPrompt(
      memory: const IlndMemory(),
      task: 'yemek yorumu yap',
      languageCode: 'en',
    );

    expect(prompt, contains('You always reply in English'));
    expect(prompt, contains('Şu anki görevin: yemek yorumu yap'));
    expect(prompt, isNot(contains('{LANG_RULE}')));
  });
}
