import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/features/habits/habit_model.dart';
import 'package:ilnd_app/features/habits/habits_repository.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Repository singleton ─────────────────────────────────────────────────────

final habitsRepositoryProvider = Provider<HabitsRepository>(
  (_) => HabitsRepository(),
);

// ── Auth-derived user ID ─────────────────────────────────────────────────────

final _userIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authNotifierProvider);
  return auth is AuthAuthenticated ? auth.user.id : null;
});

// ── Habits list ──────────────────────────────────────────────────────────────

final habitsProvider = StreamProvider<List<Habit>>((ref) {
  final userId = ref.watch(_userIdProvider);
  if (userId == null) return const Stream.empty();
  return ref.watch(habitsRepositoryProvider).habitsStream(userId);
});

// ── Today's completions ───────────────────────────────────────────────────────

final todayCompletionsProvider = StreamProvider<Set<String>>((ref) {
  final userId = ref.watch(_userIdProvider);
  if (userId == null) return const Stream.empty();
  return ref
      .watch(habitsRepositoryProvider)
      .completionsStream(userId, _today());
});

// ── Last 7 days completions — used for the grid in TakipScreen ───────────────

final last7DaysCompletionsProvider = StreamProvider<Map<String, Set<String>>>((
  ref,
) {
  final userId = ref.watch(_userIdProvider);
  if (userId == null) return const Stream.empty();
  return ref.watch(habitsRepositoryProvider).last7DaysStream(userId);
});

// ── Toggle action ─────────────────────────────────────────────────────────────

final toggleHabitCompletionProvider =
    Provider<Future<void> Function(String habitId)>((ref) {
      final userId = ref.read(_userIdProvider);
      final repo = ref.read(habitsRepositoryProvider);
      return (habitId) async {
        if (userId == null) return;
        await repo.toggleCompletion(userId, habitId, _today());
      };
    });

// ── Water today ──────────────────────────────────────────────────────────────

final waterTodayProvider = StateNotifierProvider<WaterNotifier, int>((ref) {
  return WaterNotifier(ref.watch(sharedPreferencesProvider));
});

class WaterNotifier extends StateNotifier<int> {
  WaterNotifier(this._prefs) : super(_prefs.getInt(_key()) ?? 0);

  final SharedPreferences _prefs;

  static String _key() {
    final d = DateTime.now();
    return 'water_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> add(int ml) async {
    final v = state + ml;
    state = v;
    await _prefs.setInt(_key(), v);
  }

  Future<void> reset() async {
    state = 0;
    await _prefs.remove(_key());
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

String _today() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
