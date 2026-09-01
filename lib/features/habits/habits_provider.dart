import 'package:flutter/widgets.dart';
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

// ── Geçmiş penceresi: hafta / ay ─────────────────────────────────────────────

/// Takip ekranındaki tamamlama ızgarasının genişliği.
enum TrackingRange {
  week(7),
  month(30);

  const TrackingRange(this.days);

  /// Izgarada kaç gün gösterilir.
  final int days;
}

/// Seçili pencere. Varsayılan hafta: "bu hafta ne yaptım" günlük soru,
/// ay bilerek seçilen bir uzaklaşma.
final trackingRangeProvider = StateProvider<TrackingRange>(
  (_) => TrackingRange.week,
);

/// Seçili penceredeki tamamlamalar: { 'YYYY-MM-DD': { habitId, ... } }.
final rangeCompletionsProvider =
    StreamProvider.family<Map<String, Set<String>>, TrackingRange>((
      ref,
      range,
    ) {
      final userId = ref.watch(_userIdProvider);
      if (userId == null) return const Stream.empty();
      return ref
          .watch(habitsRepositoryProvider)
          .completionsRangeStream(userId, range.days);
    });

// ── Toggle action ────────────────────────────────────────────────────────────

final toggleHabitCompletionProvider =
    Provider<Future<void> Function(String habitId)>((ref) {
      final userId = ref.read(_userIdProvider);
      final repo = ref.read(habitsRepositoryProvider);
      return (habitId) async {
        if (userId == null) return;
        await repo.toggleCompletion(userId, habitId, _today());
      };
    });

/// Alışkanlığı siler.
///
/// `HabitsRepository.deleteHabit` yazılmıştı ama hiçbir yerden
/// çağrılmıyordu: arka uç ve Firestore kuralı hazırdı, arayüzde kapı yoktu.
final deleteHabitProvider = Provider<Future<void> Function(String habitId)>((
  ref,
) {
  final repo = ref.read(habitsRepositoryProvider);
  return (habitId) => repo.deleteHabit(habitId);
});

// ── Water ────────────────────────────────────────────────────────────────────

/// Bir günün su kaydının SharedPreferences anahtarı.
String waterKey(String day) => 'water_$day';

final waterTodayProvider = StateNotifierProvider<WaterNotifier, int>((ref) {
  return WaterNotifier(ref.watch(sharedPreferencesProvider));
});

/// Bugün içilen su (ml).
///
/// Sayacın "kendiliğinden sıfırlanmasının" kaynağı gün anahtarının notifier
/// kurulurken BİR KEZ hesaplanmasıydı:
///
/// 1. Uygulama arka planda gece yarısını geçtiğinde ekran hâlâ dünün
///    toplamını gösteriyordu; üstüne eklenen ilk bardak, dünün toplamıyla
///    birlikte bugünün anahtarına yazılıyordu. Uygulama yeniden başlatılınca
///    bugünün kaydı okunuyor ve sayaç kullanıcı için sebepsizce zıplayıp
///    sıfırlanmış gibi görünüyordu.
/// 2. Yeni toplam yalnız bellekteki state'ten türetiliyordu: aynı anahtara
///    yazan ikinci bir notifier örneği (provider yeniden kurulumu, hesap
///    değişimi) araya girdiğinde son yazan diğerinin eklemesini siliyordu.
///
/// Bu yüzden gün anahtarı her okuma/yazmada yeniden hesaplanır, uygulama öne
/// geldiğinde gün sınırı denetlenir ve ekleme diskteki değerin üstüne yapılır.
class WaterNotifier extends StateNotifier<int> with WidgetsBindingObserver {
  /// [clock] yalnız test içindir: gün sınırını geçmek gerçek saatin gece
  /// yarısını beklemeden denenebilsin diye dışarıdan verilir.
  WaterNotifier(this._prefs, {DateTime Function() clock = DateTime.now})
    : _clock = clock,
      _day = _fmt(clock()),
      super(_prefs.getInt(waterKey(_fmt(clock()))) ?? 0) {
    WidgetsBinding.instance.addObserver(this);
  }

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  /// Sayacın ait olduğu gün (YYYY-MM-DD).
  String _day;

  /// Gün değiştiyse sayacı bugünün kaydına çeker.
  void syncToToday() {
    final today = _fmt(_clock());
    if (today == _day) return;
    _day = today;
    state = _prefs.getInt(waterKey(today)) ?? 0;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama geceyi arka planda geçirmiş olabilir.
    if (state == AppLifecycleState.resumed) syncToToday();
  }

  Future<void> add(int ml) async {
    syncToToday();
    final total = (_prefs.getInt(waterKey(_day)) ?? 0) + ml;
    state = total;
    await _prefs.setInt(waterKey(_day), total);
  }

  Future<void> reset() async {
    syncToToday();
    state = 0;
    await _prefs.remove(waterKey(_day));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// Seçili penceredeki günlük su kayıtları, eskiden yeniye. Kaydı olmayan gün
/// 0'dır; son eleman her zaman bugündür.
final waterHistoryProvider = Provider.family<List<int>, TrackingRange>((
  ref,
  range,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  // Bugünkü ekleme listeyi de tazelesin.
  final today = ref.watch(waterTodayProvider);
  final now = DateTime.now();
  return [
    for (var back = range.days - 1; back >= 0; back--)
      if (back == 0)
        today
      else
        prefs.getInt(waterKey(_fmt(now.subtract(Duration(days: back))))) ?? 0,
  ];
});

// ── Helpers ──────────────────────────────────────────────────────────────────

String _today() => _fmt(DateTime.now());

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
