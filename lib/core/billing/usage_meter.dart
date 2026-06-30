import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/billing/entitlement.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';

/// Ölçülen (maliyetli) AI eylem türleri.
enum UsageKind {
  /// Sohbet mesajı veya günlük karşılığı (her ikisi de AI çağrısı).
  message,

  /// Yemek fotoğrafı analizi (vision — daha pahalı).
  food,
}

/// Ücretsiz katmanın haftalık limitleri. Premium = sınırsız.
///
/// Sınırlar birim ekonomisine göre ayarlanır: her eylem token = para.
const Map<UsageKind, int> kFreeWeeklyLimits = {
  UsageKind.message: 20,
  UsageKind.food: 5,
};

/// Bir haftalık kullanım sayacı. Pazartesi sıfırlanır.
class UsageState {
  const UsageState({required this.weekKey, this.counts = const {}});

  /// İçinde bulunulan haftanın anahtarı (yıl + ISO hafta no).
  final String weekKey;

  /// Tür başına bu haftaki kullanım sayısı.
  final Map<UsageKind, int> counts;

  int countOf(UsageKind kind) => counts[kind] ?? 0;

  int remaining(UsageKind kind) =>
      (kFreeWeeklyLimits[kind] ?? 0) - countOf(kind);

  UsageState copyWith({String? weekKey, Map<UsageKind, int>? counts}) =>
      UsageState(
        weekKey: weekKey ?? this.weekKey,
        counts: counts ?? this.counts,
      );
}

const _kUsage = 'usage_meter';

final usageMeterProvider =
    StateNotifierProvider<UsageMeterNotifier, UsageState>((ref) {
      return UsageMeterNotifier(ref.watch(sharedPreferencesProvider));
    });

class UsageMeterNotifier extends StateNotifier<UsageState> {
  UsageMeterNotifier(this._prefs)
    : super(UsageState(weekKey: _currentWeekKey())) {
    _load();
  }

  final dynamic _prefs; // SharedPreferences

  static String _currentWeekKey() {
    final now = DateTime.now();
    // ISO-8601 hafta numarası yaklaşığı: yılın gününü 7'ye böl.
    final dayOfYear = int.parse(
      '${now.difference(DateTime(now.year, 1, 1)).inDays + 1}',
    );
    final week = ((dayOfYear - now.weekday + 10) ~/ 7);
    return '${now.year}-W$week';
  }

  void _load() {
    final raw = _prefs.getString(_kUsage) as String?;
    final thisWeek = _currentWeekKey();
    if (raw == null || raw.isEmpty) {
      state = UsageState(weekKey: thisWeek);
      return;
    }
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final storedWeek = j['weekKey'] as String? ?? thisWeek;
      // Hafta değiştiyse sıfırla.
      if (storedWeek != thisWeek) {
        state = UsageState(weekKey: thisWeek);
        _persist();
        return;
      }
      final rawCounts = (j['counts'] as Map?) ?? const {};
      final counts = <UsageKind, int>{};
      for (final kind in UsageKind.values) {
        final v = rawCounts[kind.name];
        if (v is int) counts[kind] = v;
      }
      state = UsageState(weekKey: storedWeek, counts: counts);
    } catch (_) {
      state = UsageState(weekKey: thisWeek);
    }
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _kUsage,
      jsonEncode({
        'weekKey': state.weekKey,
        'counts': {for (final e in state.counts.entries) e.key.name: e.value},
      }),
    );
  }

  /// Hafta sınırını geçtiysek yeni hafta anahtarıyla taze başlar.
  void _rolloverIfNeeded() {
    final thisWeek = _currentWeekKey();
    if (state.weekKey != thisWeek) {
      state = UsageState(weekKey: thisWeek);
      _persist();
    }
  }

  /// Bu türde bir eylem daha yapılabilir mi (ücretsiz katman için).
  bool canUse(UsageKind kind) {
    _rolloverIfNeeded();
    return state.remaining(kind) > 0;
  }

  /// Bir kullanımı kaydeder.
  Future<void> record(UsageKind kind) async {
    _rolloverIfNeeded();
    final counts = Map<UsageKind, int>.from(state.counts);
    counts[kind] = (counts[kind] ?? 0) + 1;
    state = state.copyWith(counts: counts);
    await _persist();
  }
}

/// Bir eylemin şu an izinli olup olmadığını premium + sayaca göre çözer.
///
/// Tek karar noktası: özellikler bunu çağırır, limit/paywall mantığını
/// tekrar etmez.
class UsageGate {
  UsageGate(this._ref);
  final Ref _ref;

  bool isAllowed(UsageKind kind) {
    if (_ref.read(isPremiumProvider)) return true;
    return _ref.read(usageMeterProvider.notifier).canUse(kind);
  }

  Future<void> record(UsageKind kind) async {
    if (_ref.read(isPremiumProvider)) return; // premium sayılmaz
    await _ref.read(usageMeterProvider.notifier).record(kind);
  }
}

final usageGateProvider = Provider<UsageGate>((ref) => UsageGate(ref));
