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

  static Future<void> seedIfEmpty() async {
    try {
      final snap = await _col.limit(1).get();
      if (snap.docs.isNotEmpty) return;

      final batch = FirebaseService.firestore.batch();
      for (final article in kArticles) {
        batch.set(_col.doc(), article.toMap());
      }
      await batch.commit();
    } catch (e) {
      // seed hatası uygulamayı çökertmesin
    }
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final articlesProvider = StreamProvider<List<Article>>((ref) {
  return ExploreRepository.stream();
});
