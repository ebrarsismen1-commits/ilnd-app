import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ilnd_app/core/repositories/explore_repository.dart';
import 'package:ilnd_app/features/explore/article_model.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';

/// Günün tarifi: tarif kategorisindeki makalelerden, kullanıcının beslenme
/// tercihi ve alerjilerine göre süzülüp gün üzerinden dönerek seçilir.
///
/// Güvenlik önceliği ALERJİ süzgecindedir: kullanıcının alerjeni geçen
/// tarif asla önerilmez (Article.allergens tutucu etiketlenir). Diyet
/// süzgeci ikincildir: uygun tarif kalmazsa diyet gevşetilir ama alerji
/// süzgeci asla gevşetilmez.
final trioRecipeProvider = Provider<Article?>((ref) {
  // Explore ile aynı kaynak: Firestore geldiyse o, yoksa offline fallback.
  final fetched = ref.watch(articlesProvider).valueOrNull;
  final source = (fetched == null || fetched.isEmpty) ? kArticles : fetched;
  final diet = ref.watch(onboardingDietProvider);
  final allergies = ref.watch(onboardingAllergiesProvider);

  return selectRecipeForDay(
    articles: source,
    day: DateTime.now(),
    diet: diet,
    allergies: allergies,
  );
});

/// Saf seçim mantığı — provider'sız test edilir.
Article? selectRecipeForDay({
  required List<Article> articles,
  required DateTime day,
  required String? diet,
  required List<String> allergies,
}) {
  final recipes = articles
      .where((a) => a.category == ArticleCategory.tarif && a.isRecipe)
      .toList();
  if (recipes.isEmpty) return null;

  // 1) Alerji süzgeci — pazarlıksız.
  final safe = recipes
      .where((r) => !r.allergens.any(allergies.contains))
      .toList();
  if (safe.isEmpty) return null; // hiç güvenli tarif yok → kart gösterilmez

  // 2) Diyet süzgeci — uygun kalmazsa gevşer (alerji süzgeci korunarak).
  var eligible = safe;
  if (diet != null && diet != 'yok') {
    final matching = safe.where((r) => r.diets.contains(diet)).toList();
    if (matching.isNotEmpty) eligible = matching;
  }

  final dayOfYear = day.difference(DateTime(day.year)).inDays;
  return eligible[dayOfYear % eligible.length];
}

// ─── Günlük tamamlama tikleri ─────────────────────────────────────────────────

const _kTrioDate = 'trio_done_date';
const _kTrioItems = 'trio_done_items';

/// Hareket/Tabak tamamlama durumu — cihazda günlük (todaysMood deseni):
/// tarih değişince kendiliğinden sıfırlanır. 'move' ve 'plate' anahtarları.
final trioDoneProvider = StateNotifierProvider<TrioDoneNotifier, Set<String>>((
  ref,
) {
  return TrioDoneNotifier(ref.watch(sharedPreferencesProvider));
});

class TrioDoneNotifier extends StateNotifier<Set<String>> {
  TrioDoneNotifier(this._prefs) : super(_readIfToday(_prefs));

  final SharedPreferences _prefs;

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Set<String> _readIfToday(SharedPreferences prefs) {
    if (prefs.getString(_kTrioDate) != _today()) return const {};
    return (prefs.getStringList(_kTrioItems) ?? const []).toSet();
  }

  Future<void> toggle(String item) async {
    final updated = {...state};
    if (!updated.remove(item)) updated.add(item);
    state = updated;
    await _prefs.setString(_kTrioDate, _today());
    await _prefs.setStringList(_kTrioItems, updated.toList());
  }
}
