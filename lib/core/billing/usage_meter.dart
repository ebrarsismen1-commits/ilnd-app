import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/billing/entitlement.dart';
import 'package:ilnd_app/core/repositories/referral_repository.dart';
import 'package:ilnd_app/core/services/firebase_service.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';

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
/// functions/index.js'teki FREE_WEEKLY_LIMITS ile birebir aynı olmalı —
/// gerçek karar sunucuda verilir, buradaki kopya yalnız arayüz içindir
/// (kalan hak, paywall'ı çağrı yapmadan açabilmek).
const Map<UsageKind, int> kFreeWeeklyLimits = {
  UsageKind.message: 20,
  UsageKind.food: 5,
};

/// UTC tabanlı, PAZARTESİ başlayan hafta kovası (ör. "W2951").
///
/// functions/index.js'teki `currentWeekKey` ile BİREBİR aynı formül: farklı
/// olurlarsa istemci sunucunun yazdığından başka bir dokümanı okur ve kalan
/// hak yanlış görünür. Epoch günü 0 = 1 Ocak 1970 Perşembe, bu yüzden +3
/// kaydırma kovaları pazartesiye hizalar. Yerel saat dilimi bilerek
/// kullanılmaz — saat dilimi değiştirmek haftayı sıfırlamamalı.
String usageWeekKey([DateTime? now]) {
  final days =
      (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
  return 'W${(days + 3) ~/ 7}';
}

/// Bir haftalık kullanım sayacı. Pazartesi sıfırlanır.
class UsageState {
  const UsageState({required this.weekKey, this.counts = const {}});

  /// İçinde bulunulan haftanın anahtarı (bkz. [usageWeekKey]).
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

/// Hesabın haftalık sayaç dokümanını (`ai_usage/{uid}_{hafta}`) izler.
///
/// Doküman yalnız sunucuda (anthropicProxy, Admin SDK) yazılır; kurallar
/// istemciye sadece okuma verir. Bu yüzden sayaç cihazdan bağımsızdır:
/// kullanıcı web'e geçse, uygulamayı silip kursa da aynı sayaç okunur.
Stream<UsageState> watchAccountUsage(String uid) {
  final week = usageWeekKey();
  return FirebaseService.firestore
      .collection('ai_usage')
      .doc('${uid}_$week')
      .snapshots()
      .map((doc) {
        final data = doc.data() ?? const <String, dynamic>{};
        final rawCounts = (data['counts'] as Map?) ?? const {};
        final counts = <UsageKind, int>{};
        for (final kind in UsageKind.values) {
          final v = rawCounts[kind.name];
          if (v is int) counts[kind] = v;
        }
        return UsageState(weekKey: week, counts: counts);
      });
}

final usageMeterProvider =
    StateNotifierProvider<UsageMeterNotifier, UsageState>((ref) {
      // Kural #2: hem köprü oturumunu hem hesabı izle. Köprü bitmeden açılan
      // stream permission-denied ile ölür ve Firestore stream'i kendini
      // yenilemez; hesap değişince de sayaç sıfırdan kurulmalı.
      final fbUid = ref.watch(firebaseAuthUidProvider).valueOrNull;
      final auth = ref.watch(authNotifierProvider);
      final uid = auth is AuthAuthenticated ? auth.user.id : null;
      final remote = (fbUid == null || uid == null)
          ? const Stream<UsageState>.empty()
          : watchAccountUsage(uid);
      return UsageMeterNotifier(remote);
    });

class UsageMeterNotifier extends StateNotifier<UsageState> {
  UsageMeterNotifier(Stream<UsageState> remote)
    : super(UsageState(weekKey: usageWeekKey())) {
    _sub = remote.listen(
      _onRemote,
      // Ağ/izin hatasında sayaç görünmez olur; kullanıcıyı bloklamak yerine
      // izin ver — asıl sınır zaten sunucuda uygulanıyor (429 döner).
      onError: (Object _) {},
    );
  }

  StreamSubscription<UsageState>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onRemote(UsageState remote) {
    if (!mounted) return;
    final thisWeek = usageWeekKey();
    // Uygulama açıkken hafta döndüyse elimizdeki stream hâlâ geçen haftanın
    // dokümanını dinliyor olabilir — o veriyi yeni haftaya taşıma.
    if (remote.weekKey != thisWeek) return;
    if (state.weekKey != thisWeek) {
      state = remote;
      return;
    }
    // Sunucu doğruyu söyler, ama uçuşta olan bir çağrının yerel artışı geri
    // düşmesin (snapshot gecikirse kullanıcı bir hak fazladan denemesin).
    final merged = <UsageKind, int>{};
    for (final kind in UsageKind.values) {
      final value = math.max(state.countOf(kind), remote.countOf(kind));
      if (value > 0) merged[kind] = value;
    }
    state = state.copyWith(counts: merged);
  }

  /// Hafta sınırını geçtiysek yeni hafta anahtarıyla taze başlar.
  void _rolloverIfNeeded() {
    final thisWeek = usageWeekKey();
    if (state.weekKey != thisWeek) {
      state = UsageState(weekKey: thisWeek);
    }
  }

  /// Bu türde bir eylem daha yapılabilir mi (ücretsiz katman için).
  bool canUse(UsageKind kind) {
    _rolloverIfNeeded();
    return state.remaining(kind) > 0;
  }

  /// Bir kullanımı yerel olarak işaretler.
  ///
  /// Gerçek sayaç sunucuda, çağrı sırasında artar; bu yalnız snapshot gelene
  /// kadar arayüzün doğru kalan hakkı göstermesi içindir.
  void record(UsageKind kind) {
    _rolloverIfNeeded();
    final counts = Map<UsageKind, int>.from(state.counts);
    counts[kind] = (counts[kind] ?? 0) + 1;
    state = state.copyWith(counts: counts);
  }

  /// Sunucu 429 (haftalık kota doldu) dediğinde sayacı doluya çeker.
  ///
  /// Başka bir cihazda harcanan hak yüzünden yerel sayaç geride kalmış
  /// olabilir; bu olmadan kullanıcı her denemede aynı duvara çarpar.
  void markExhausted(UsageKind kind) {
    _rolloverIfNeeded();
    final counts = Map<UsageKind, int>.from(state.counts);
    counts[kind] = kFreeWeeklyLimits[kind] ?? 0;
    state = state.copyWith(counts: counts);
  }
}

/// Bir eylemin şu an izinli olup olmadığını premium + sayaca göre çözer.
///
/// Tek karar noktası: özellikler bunu çağırır, limit/paywall mantığını
/// tekrar etmez. Not: bu yalnız arayüz kararıdır (paywall'ı çağrı yapmadan
/// açmak için); gerçek sınırı sunucu uygular.
class UsageGate {
  UsageGate(this._ref);
  final Ref _ref;

  /// Cihaz-yerel mağaza hakkı VEYA hesaba bağlı ödül premium'u. İkincisi
  /// olmadan, daveti kabul edilmiş bir kullanıcı ikinci cihazında ücretsiz
  /// katman sınırına takılırdı — sunucu onu premium sayarken.
  bool get _isPremium {
    if (_ref.read(isPremiumProvider)) return true;
    final growth = _ref.read(myGrowthProfileProvider).valueOrNull;
    return growth?.hasActivePremiumReward ?? false;
  }

  bool isAllowed(UsageKind kind) {
    if (_isPremium) return true;
    return _ref.read(usageMeterProvider.notifier).canUse(kind);
  }

  void record(UsageKind kind) {
    if (_isPremium) return; // premium sayılmaz
    _ref.read(usageMeterProvider.notifier).record(kind);
  }

  void markExhausted(UsageKind kind) =>
      _ref.read(usageMeterProvider.notifier).markExhausted(kind);
}

final usageGateProvider = Provider<UsageGate>((ref) => UsageGate(ref));
