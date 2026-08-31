import 'package:ilnd_app/features/explore/article_model.dart';
import 'package:ilnd_app/features/home/daily_read.dart';

/// Keşfet'in kapak ve liste sıralaması.
///
/// Üç sorunu birden çözer:
///
/// 1. **Kapak dönmüyordu.** `allArticles.first` idi, yani Firestore ne
///    döndürürse hep o. Artık dakikaya bağlı: ekrana her girişte ve dakika
///    ilerledikçe başka bir yazı öne çıkar.
/// 2. **Liste konu konu yığılıydı.** İçerik sprint sprint tohumlandığı için
///    ham sıra "15 meditasyon, sonra 12 egzersiz, sonra 18 öz bakım" gibi
///    geliyordu. Artık kategoriler dönüşümlü diziliyor.
/// 3. **Kişiselleştirme yoktu.** Onboarding hedeflerine karşılık gelen
///    kategoriler listenin başında yer alır.
///
/// Sıralama **deterministik**: rastgele karıştırma her yeniden çizimde listeyi
/// değiştirir ve kullanıcı yerini kaybeder. Aynı hedeflerle aynı kütüphane
/// hep aynı sırayı verir.

/// Kategorileri kullanıcının ilgi alanı önce gelecek şekilde sıralar.
///
/// İlgi alanı bir filtre değil: eşleşmeyen kategoriler listeden atılmaz,
/// arkaya alınır. Kullanıcı yalnız hareket seçtiyse de diğer konuları
/// görmeye devam eder.
List<ArticleCategory> orderedCategories(Iterable<String> goals) {
  final wanted = categoriesForGoals(goals);
  final preferred = ArticleCategory.values.where(wanted.contains);
  final rest = ArticleCategory.values.where((c) => !wanted.contains(c));
  return [...preferred, ...rest];
}

/// Kategorileri dönüşümlü dizerek listeyi karar.
///
/// Round-robin: her turda her kategoriden bir yazı alınır. Böylece aynı konu
/// arka arkaya yığılmaz ama sıra rastgele de olmaz.
List<Article> orderedFeed({
  required List<Article> library,
  required Iterable<String> goals,
}) {
  if (library.isEmpty) return const [];

  final buckets = <ArticleCategory, List<Article>>{};
  for (final article in library) {
    buckets.putIfAbsent(article.category, () => []).add(article);
  }
  // Kova içi sıra da sabitlenmeli: Firestore sıra garantisi vermiyor.
  for (final bucket in buckets.values) {
    bucket.sort((a, b) => a.id.compareTo(b.id));
  }

  final order = orderedCategories(goals).where(buckets.containsKey).toList();

  final feed = <Article>[];
  var round = 0;
  while (feed.length < library.length) {
    var added = false;
    for (final category in order) {
      final bucket = buckets[category]!;
      if (round < bucket.length) {
        feed.add(bucket[round]);
        added = true;
      }
    }
    // Güvenlik kemeri: hiçbir kovadan alınamadıysa sonsuz döngüye girme.
    if (!added) break;
    round++;
  }
  return feed;
}

/// Epoch'tan bu yana geçen tam dakika sayısı.
///
/// UTC üzerinden: saat dilimi değişikliği kapağı geri sarmamalı.
int minutesSinceEpoch(DateTime now) =>
    now.toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerMinute;

/// Kapaktaki yazı. Dakikada bir değişir.
///
/// [goals] verilmişse ilgi alanına uyanlar arasından seçilir; eşleşme yoksa
/// tüm kütüphaneye düşülür (kişiselleştirme filtreye dönüşmez).
Article? pickHero({
  required List<Article> library,
  required Iterable<String> goals,
  required DateTime now,
}) {
  if (library.isEmpty) return null;

  final wanted = categoriesForGoals(goals);
  final preferred = wanted.isEmpty
      ? library
      : library.where((a) => wanted.contains(a.category)).toList();
  final pool = preferred.isEmpty ? library : preferred;

  final sorted = [...pool]..sort((a, b) => a.id.compareTo(b.id));
  return sorted[minutesSinceEpoch(now) % sorted.length];
}
