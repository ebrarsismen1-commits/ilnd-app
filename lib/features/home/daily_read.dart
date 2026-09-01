import 'package:ilnd_app/features/explore/article_model.dart';

/// Ana ekrandaki "bugünün okuması" seçimi.
///
/// İki kural:
///
/// 1. **Saat başı değişir.** Önceki hâli `kArticles[DateTime.now().day % ...]`
///    idi: günde bir kez dönüyordu ve yalnız 15 maddelik çevrimdışı yedeğe
///    bakıyordu, yani Firestore'daki asıl kütüphane (içerik sprintlerinin
///    yazıları) ana ekranda hiç görünmüyordu.
/// 2. **İlgi alanına öncelik verir.** Onboarding'de seçilen hedefler
///    kategorilere eşlenir; eşleşen yazı varsa seçim onların içinden yapılır.
///    Eşleşme yoksa tüm kütüphane kullanılır, yani ekran asla boş kalmaz.
///
/// Seçim deterministiktir: aynı saatte, aynı hedeflerle, aynı kütüphaneden
/// hep aynı yazı çıkar. Test edilebilmesi için [now] dışarıdan verilir.

/// Onboarding hedefinin karşılığı olan içerik kategorisi.
///
/// Anahtarlar quick_setup_screen.dart'taki `_goals` listesinden gelir;
/// oraya yeni hedef eklenirse buraya da satır eklenmeli (eklenmezse hedef
/// sessizce "ilgi alanı yok" sayılır, hata vermez).
ArticleCategory? categoryForGoal(String goal) => switch (goal) {
  'kalori_besin_takibi' => ArticleCategory.beslenme,
  'kilo_vermek_almak' => ArticleCategory.beslenme,
  'daha_fazla_hareket' => ArticleCategory.hareket,
  'su_uyku_takibi' => ArticleCategory.ozBakim,
  'aliskanlik_olusturma' => ArticleCategory.gelisim,
  'ruh_hali_takibi' => ArticleCategory.meditasyon,
  _ => null,
};

/// [goals] listesinin karşılık geldiği kategoriler.
Set<ArticleCategory> categoriesForGoals(Iterable<String> goals) =>
    goals.map(categoryForGoal).whereType<ArticleCategory>().toSet();

/// Epoch'tan bu yana geçen tam saat sayısı.
///
/// UTC üzerinden hesaplanır: saat dilimi değişikliği seçimi geri sarmamalı
/// (usage_meter.dart'taki hafta kovasıyla aynı gerekçe).
int hoursSinceEpoch(DateTime now) =>
    now.toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerHour;

/// Bu saatin okuması. Kütüphane boşsa `null` döner, çağıran yedeğine düşer.
Article? pickHourlyRead({
  required List<Article> library,
  required Iterable<String> goals,
  required DateTime now,
}) {
  if (library.isEmpty) return null;

  final wanted = categoriesForGoals(goals);
  final preferred = wanted.isEmpty
      ? library
      : library.where((a) => wanted.contains(a.category)).toList();

  // İlgi alanına uyan yazı yoksa kütüphanenin tamamına düş: kişiselleştirme
  // bir filtre değil, sıralama tercihi. Boş ekran göstermek daha kötü.
  final pool = preferred.isEmpty ? library : preferred;

  // Firestore liste sırasını garanti etmiyor; id'ye göre sıralamak aynı
  // saatte aynı yazının çıkmasını sağlar.
  final sorted = [...pool]..sort((a, b) => a.id.compareTo(b.id));

  return sorted[hoursSinceEpoch(now) % sorted.length];
}
