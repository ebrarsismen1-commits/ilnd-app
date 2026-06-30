import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';

// Key format: intention_2024-06-15
String _intentionKey(DateTime date) =>
    'intention_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

final dailyIntentionProvider =
    StateNotifierProvider<DailyIntentionNotifier, String?>((ref) {
      return DailyIntentionNotifier(ref.watch(sharedPreferencesProvider));
    });

class DailyIntentionNotifier extends StateNotifier<String?> {
  DailyIntentionNotifier(this._prefs)
    : super(_prefs.getString(_intentionKey(DateTime.now())));

  final SharedPreferences _prefs;

  Future<void> save(String intention) async {
    final trimmed = intention.trim();
    state = trimmed.isEmpty ? null : trimmed;
    if (trimmed.isNotEmpty) {
      await _prefs.setString(_intentionKey(DateTime.now()), trimmed);
    }
  }

  void clear() {
    state = null;
  }
}
