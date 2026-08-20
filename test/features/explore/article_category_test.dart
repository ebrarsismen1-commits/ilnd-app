import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/features/explore/article_model.dart';

/// Editoryal kategoriler (owner kararı 2026-08-20) ve eski değerlerin geçişi.
///
/// Kategori sistemi üçlüden beşliye çıkarken asıl risk şuydu: yayındaki
/// Firestore dokümanları hâlâ `tarif` / `wellness` / `yazi` yazıyor. Eşleme
/// olmasaydı `fromString` hepsini varsayılana düşürürdü ve her makale
/// sessizce yanlış kategoriye girerdi — kimse hata görmez, sadece filtreler
/// saçmalardı.
void main() {
  test('altı editoryal kategori, içerik planındaki sırayla', () {
    // Tarif, beslenmeden 2026-08-20'de ayrıldı: owner "Ozempic haberiyle
    // nohut salatası neden aynı yerde" dedi ve haklıydı, ikisi farklı
    // içerik türü.
    expect(ArticleCategory.values, [
      ArticleCategory.meditasyon,
      ArticleCategory.beslenme,
      ArticleCategory.tarif,
      ArticleCategory.hareket,
      ArticleCategory.ozBakim,
      ArticleCategory.gelisim,
    ]);
  });

  test('eski Firestore değerleri yeni kategorilere taşınır', () {
    // tarif artık gerçek bir kategori: kendisine çözülüyor.
    expect(ArticleCategoryX.fromString('tarif'), ArticleCategory.tarif);
    expect(ArticleCategoryX.fromString('wellness'), ArticleCategory.ozBakim);
    expect(ArticleCategoryX.fromString('yazi'), ArticleCategory.gelisim);
  });

  test('yeni değerler kendilerine çözülür', () {
    for (final c in ArticleCategory.values) {
      expect(ArticleCategoryX.fromString(c.firestoreValue), c);
    }
  });

  test('tanınmayan değer uygulamayı kırmaz', () {
    expect(
      ArticleCategoryX.fromString('bilinmeyen-kategori'),
      ArticleCategory.gelisim,
    );
    expect(ArticleCategoryX.fromString(''), ArticleCategory.gelisim);
  });

  test('her kategorinin etiketi ve paleti var', () {
    for (final c in ArticleCategory.values) {
      expect(c.tag, isNotEmpty);
      // EditorialGradient dört palet taşıyor.
      expect(c.palette, inInclusiveRange(0, 3));
    }
  });

  group('tarif ayrımı içerikte de tutuyor', () {
    // Kategori kod tarafında ayrıldı ama asıl risk içerikte: bir tarif
    // "beslenme" kalırsa Tarifler sekmesinde hiç görünmez, bir makale
    // "tarif" olursa malzemesiz bir tarif kartı olarak çıkar. İkisi de
    // sessiz hata.
    final raw = File('content/articles.json').readAsStringSync();
    final items = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();

    bool isRecipeData(Map<String, dynamic> a) =>
        (a['ingredients'] as List? ?? []).isNotEmpty &&
        (a['steps'] as List? ?? []).isNotEmpty;

    test('içerik dosyasında tarif kategorisi kullanılıyor', () {
      expect(items.where((a) => a['category'] == 'tarif'), isNotEmpty);
    });

    test('malzeme + adım taşıyan her yazı tarif kategorisinde', () {
      for (final a in items.where(isRecipeData)) {
        expect(
          a['category'],
          'tarif',
          reason: '${a['id']}: tarif ama kategorisi ${a['category']}',
        );
      }
    });

    test('tarif kategorisindeki her yazının malzemesi ve adımı var', () {
      for (final a in items.where((a) => a['category'] == 'tarif')) {
        expect(
          isRecipeData(a),
          isTrue,
          reason: '${a['id']}: tarif kategorisinde ama tarif değil',
        );
      }
    });

    test('yerleşik kArticles yedeğinde de aynı ayrım geçerli', () {
      // Firestore boşken ekranda bu liste var; ayrım orada da tutmalı.
      for (final a in kArticles) {
        expect(
          a.isRecipe,
          a.category == ArticleCategory.tarif,
          reason: '${a.id}: kategori ile tarif olma durumu uyuşmuyor',
        );
      }
    });
  });
}
