import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/features/explore/article_model.dart';

/// İngilizce kullanıcı Türkçe içerik GÖRMEMELİ: makale, uygulama diline göre
/// çevrilir; çevirisi olmayan alan Türkçesine düşer (asla boş ekran).
void main() {
  const article = Article(
    id: 'dikkatle-hareket',
    title: 'dikkatle hareket',
    category: ArticleCategory.wellness,
    readTime: '4 dk',
    excerpt: 'TR özet',
    body: ['TR paragraf'],
    ingredients: ['TR malzeme'],
    steps: ['TR adım'],
    en: ArticleTranslation(
      title: 'moving with attention',
      readTime: '4 min',
      excerpt: 'EN excerpt',
      body: ['EN paragraph'],
    ),
  );

  test('en locale: çevrili alanlar İngilizce gelir', () {
    final localized = article.forLocale('en');
    expect(localized.title, 'moving with attention');
    expect(localized.readTime, '4 min');
    expect(localized.excerpt, 'EN excerpt');
    expect(localized.body, ['EN paragraph']);
    // Kimliği değişmez — ritüel rayı id ile eşleşmeye devam eder.
    expect(localized.id, 'dikkatle-hareket');
  });

  test('en locale: çeviride eksik alan Türkçesine düşer', () {
    final localized = article.forLocale('en');
    expect(localized.ingredients, ['TR malzeme']);
    expect(localized.steps, ['TR adım']);
  });

  test('tr locale: makale olduğu gibi kalır', () {
    final localized = article.forLocale('tr');
    expect(identical(localized, article), isTrue);
  });

  test('çevirisi olmayan makale en locale altında da Türkçe kalır', () {
    const noEn = Article(
      id: 'x',
      title: 'başlık',
      category: ArticleCategory.yazi,
      readTime: '3 dk',
      excerpt: 'özet',
      body: ['gövde'],
    );
    expect(identical(noEn.forLocale('en'), noEn), isTrue);
  });

  test('kArticles yedeğinin tamamı EN çevirili', () {
    expect(kArticles.where((a) => a.en == null), isEmpty);
  });
}
