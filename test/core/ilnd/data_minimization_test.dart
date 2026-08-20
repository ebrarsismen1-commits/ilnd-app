import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/ilnd/ilnd_character.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/ilnd/ilnd_service.dart';

/// Veri minimizasyonu sözleşmesi (KVKK gerekçesi, 2026-08-11):
/// AI sağlayıcısına giden gövdede kullanıcının **adı bulunmaz** ve **not
/// penceresi sınırlıdır**. İkisi de sessizce geri alınabilecek türden
/// kararlar — biri prompt'a bir alan eklerken, diğeri hafıza limiti
/// değişirken. Bu yüzden testle kilitleniyorlar.
void main() {
  const gizliAd = 'Ebrar';

  IlndMemory memoryWith({int noteCount = 0}) => IlndMemory(
    name: gizliAd,
    goals: const ['erken kalkmak'],
    facts: const ['vejetaryen'],
    recentNotes: [for (var i = 1; i <= noteCount; i++) 'not $i'],
  );

  group('Ad cihazdan çıkmaz', () {
    test('prompt bağlamında gerçek ad yerine jeton bulunur', () {
      final ctx = memoryWith().toPromptContext();
      expect(ctx, contains(kNamePlaceholder));
      expect(
        ctx,
        isNot(contains(gizliAd)),
        reason: 'Gerçek ad AI isteğine hiç girmemeli',
      );
    });

    test('sistem prompt\'unun tamamında da ad geçmez', () {
      final prompt = IlndCharacter.systemPrompt(memory: memoryWith());
      expect(
        prompt,
        isNot(contains(gizliAd)),
        reason: 'Sızıntı prompt\'un başka bir yerinden de olmamalı',
      );
      expect(prompt, contains(kNamePlaceholder));
    });

    test('adı olmayan kullanıcı için jeton hiç eklenmez', () {
      const ctx = IlndMemory(goals: ['uyumak']);
      expect(ctx.toPromptContext(), isNot(contains(kNamePlaceholder)));
    });
  });

  group('personalize', () {
    test('jetonu gerçek adla değiştirir', () {
      expect(
        personalize('merhaba $kNamePlaceholder, bugün nasılsın?', gizliAd),
        'merhaba Ebrar, bugün nasılsın?',
      );
    });

    test('birden çok jetonu da değiştirir', () {
      expect(
        personalize('$kNamePlaceholder... $kNamePlaceholder!', 'Ada'),
        'Ada... Ada!',
      );
    });

    test('ad yoksa jeton ekranda kalmaz', () {
      // "merhaba {ad}" diye seslenen bir ürün kırık görünür.
      final out = personalize('merhaba $kNamePlaceholder, nasılsın?', '');
      expect(out, isNot(contains(kNamePlaceholder)));
      expect(out, 'merhaba nasılsın?');
    });

    test('jeton yoksa metne dokunulmaz', () {
      const text = 'bugün kendine iyi davran.';
      expect(personalize(text, gizliAd), text);
    });
  });

  group('Not penceresi kırpılır', () {
    test('sınırdan fazla not gönderilmez', () {
      final ctx = memoryWith(noteCount: 20).toPromptContext();
      final gonderilen = RegExp('not \\d+').allMatches(ctx).length;
      expect(gonderilen, IlndMemory.promptNotesLimit);
    });

    test('gönderilenler EN YENİ notlardır', () {
      final ctx = memoryWith(noteCount: 20).toPromptContext();
      expect(ctx, contains('not 20'));
      expect(
        ctx,
        isNot(contains('not 1 ')),
        reason: 'Kırpma baştan yapılır, en yeni bağlam korunur',
      );
    });

    test('sınırın altındaki not sayısı olduğu gibi gider', () {
      final ctx = memoryWith(noteCount: 3).toPromptContext();
      expect(RegExp('not \\d+').allMatches(ctx).length, 3);
    });
  });
}
