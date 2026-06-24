import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/services/firebase_service.dart';
import 'package:ilnd_app/features/explore/article_model.dart';

class ExploreRepository {
  static final _col = FirebaseService.firestore.collection('articles');

  // Firestore'dan gerçek zamanlı makale akışı
  static Stream<List<Article>> stream() => _col
      .orderBy('order')
      .snapshots()
      .map((s) => s.docs.map(Article.fromDoc).toList());

  // İlk açılışta collection boşsa kArticles'ı yükle (one-time seeder)
  static Future<void> seedIfEmpty() async {
    final snap = await _col.limit(1).get();
    if (snap.docs.isNotEmpty) return; // zaten var, geç

    final batch = FirebaseService.firestore.batch();
    for (final article in kArticles) {
      final ref = _col.doc();
      batch.set(ref, article.toMap());
    }
    await batch.commit();
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final articlesProvider = StreamProvider<List<Article>>((ref) {
  return ExploreRepository.stream();
});
