import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/features/explore/article_model.dart';

/// Tariflerin porsiyon başına besin değerleri.
///
/// Değerler yaklaşık ve elle hesaplanıyor, o yüzden asıl risk sessiz
/// tutarsızlık: porsiyon sayısı yazılmadan kalori yazmak, makroların
/// kaloriyle uyuşmaması, ya da bir tarifin değerlerinin hiç girilmemesi.
/// Bu testler onları yakalar.
void main() {
  final raw = File('content/articles.json').readAsStringSync();
  final items = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();

  final recipes = items
      .where(
        (a) =>
            (a['ingredients'] as List? ?? []).isNotEmpty &&
            (a['steps'] as List? ?? []).isNotEmpty,
      )
      .toList();

  test('içerik dosyasında tarif var', () {
    expect(recipes, isNotEmpty);
  });

  group('besin değerleri', () {
    test('değeri olan her tarif porsiyon sayısını da yazar', () {
      for (final r in recipes) {
        final n = r['nutrition'] as Map<String, dynamic>?;
        if (n == null) continue;
        expect(
          (n['servings'] as num?)?.toInt(),
          isNotNull,
          reason:
              '${r['id']}: porsiyon sayısı yok. Kalori kaç kişiye '
              'bölündüğü bilinmeden anlamsız.',
        );
        expect((n['servings'] as num).toInt(), greaterThan(0));
      }
    });

    test('makrolar kaloriyle tutarlı', () {
      // 4/4/9 kuralı: protein ve karbonhidrat gramı 4, yağ 9 kcal.
      // Elle hesapta yazım hatası olursa toplam ciddi biçimde kayar; bu
      // yüzden geniş ama boş olmayan bir bant kullanılıyor.
      for (final r in recipes) {
        final n = r['nutrition'] as Map<String, dynamic>?;
        if (n == null) continue;
        final protein = (n['protein'] as num).toInt();
        final karb = (n['karbonhidrat'] as num).toInt();
        final yag = (n['yag'] as num).toInt();
        final kalori = (n['kalori'] as num).toInt();
        final hesap = protein * 4 + karb * 4 + yag * 9;

        expect(
          hesap,
          inInclusiveRange((kalori * 0.75).round(), (kalori * 1.25).round()),
          reason:
              '${r['id']}: makrolardan hesaplanan $hesap kcal, yazılan '
              '$kalori kcal ile uyuşmuyor.',
        );
      }
    });

    test('modele okunduğunda değerler korunur', () {
      final withNutrition = recipes.firstWhere(
        (r) => r['nutrition'] != null,
        orElse: () => <String, dynamic>{},
      );
      if (withNutrition.isEmpty) return;

      final n = RecipeNutrition.fromMap(
        Map<String, dynamic>.from(withNutrition['nutrition'] as Map),
      );
      expect(n.kalori, greaterThan(0));
      expect(n.toMap()['kalori'], n.kalori);
      expect(n.toMap()['servings'], n.servings);
    });
  });

  test('çevrimdışı liste içerik dosyasıyla aynı değerleri taşır', () {
    // kArticles ağ yokken gösterilen yedek. Değerler orada eksik kalırsa
    // aynı tarif çevrimiçi 200 kcal, çevrimdışı hiçbir şey gösterir.
    for (final a in kArticles.where((a) => a.isRecipe)) {
      final source = items.firstWhere(
        (m) => m['id'] == a.id,
        orElse: () => <String, dynamic>{},
      );
      if (source.isEmpty) continue;
      final expected = source['nutrition'] as Map<String, dynamic>?;
      if (expected == null) continue;

      expect(
        a.nutrition,
        isNotNull,
        reason: '\${a.id}: içerik dosyasında değer var, çevrimdışı listede yok',
      );
      expect(a.nutrition!.kalori, (expected['kalori'] as num).toInt());
      expect(a.nutrition!.servings, (expected['servings'] as num).toInt());
    }
  });

  test('eksik değer uygulamayı kırmaz', () {
    // Besin değeri olmayan tarif normaldir: yazılarda hiç olmaz, eski
    // tariflerde henüz girilmemiş olabilir. Ekran o zaman bölümü çizmez.
    const n = RecipeNutrition(
      servings: 1,
      kalori: 0,
      protein: 0,
      karbonhidrat: 0,
      yag: 0,
    );
    expect(n.lif, isNull);
    expect(RecipeNutrition.fromMap(const {}).servings, 1);
  });
}
