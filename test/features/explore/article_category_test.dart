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
  test('beş editoryal kategori, içerik planındaki sırayla', () {
    expect(ArticleCategory.values, [
      ArticleCategory.meditasyon,
      ArticleCategory.beslenme,
      ArticleCategory.hareket,
      ArticleCategory.ozBakim,
      ArticleCategory.gelisim,
    ]);
  });

  test('eski Firestore değerleri yeni kategorilere taşınır', () {
    // tarif → beslenme: eski içeriğin tamamı yemek tarifiydi.
    expect(ArticleCategoryX.fromString('tarif'), ArticleCategory.beslenme);
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
}
