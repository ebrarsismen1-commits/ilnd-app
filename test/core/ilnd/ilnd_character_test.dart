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

  test('Türkçe dil kuralı çeviri-kokan Türkçeyi açıkça yasaklar', () {
    final prompt = IlndCharacter.systemPrompt(memory: const IlndMemory());

    // Kural tek satıra ("Türkçe konuşursun") indirgenirse model İngilizce
    // kurduğu cümleyi Türkçe kelimelerle diziyordu: kullanıcı "welcome back"
    // karşılığında "hoş geldin geri" gördü. Bu üç madde o geri dönüşü engeller.
    expect(
      prompt,
      contains('baştan Türkçe'),
      reason: 'Çevirme değil Türkçe düşünme talimatı kaybolmuş.',
    );
    expect(
      prompt,
      contains('hoş geldin geri'),
      reason: 'Somut karşı-örnek kaybolmuş; soyut kural yeterli olmadı.',
    );
    expect(
      prompt,
      contains('"sen" diye hitap'),
      reason: 'Sen/siz kuralı kaybolmuş — resmî kalıplar geri gelir.',
    );
    expect(
      prompt,
      contains('söz dizimi'),
      reason: 'Söz dizimi kuralı kaybolmuş.',
    );
  });

  test('İngilizce dilde Türkçeye özel kural gönderilmez', () {
    final prompt = IlndCharacter.systemPrompt(
      memory: const IlndMemory(),
      languageCode: 'en',
    );

    // Türkçe kural bloğu İngilizce oturuma sızarsa model karışık dil üretir.
    expect(prompt, isNot(contains('hoş geldin geri')));
    expect(prompt, isNot(contains('baştan Türkçe')));
  });
}
