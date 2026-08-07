import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/services/firebase_service.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/features/plans/plan_model.dart';

/// Aktif plan kimliğinin tutulduğu doküman. Ayrı bir doküman, çünkü "hangi
/// plan aktif" bir plana ait veri değil, kullanıcıya ait tek bir durum
/// (ADR-0005: aynı anda tek aktif plan).
const kPlanStateDocId = '_state';

/// Plan kataloğu (ADR-0005) — herkese aynı, salt okunur içerik.
class PlanCatalogRepository {
  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseService.firestore.collection('plans');

  static Stream<List<Plan>> stream() => _col
      .orderBy('order')
      .snapshots()
      .map((s) => s.docs.map(Plan.fromDoc).toList());
}

/// Kullanıcının plan ilerlemesi — `users/{uid}/plan_progress/{planId}`.
///
/// İlerleme kota/hak değildir (Sert Kural #13 yalnız sınır/kota içindir), bu
/// yüzden istemci yazabilir; yer `users/{uid}` altı olduğundan mevcut
/// sahiplik kuralı yeterli, ayrı rule gerekmez.
class PlanProgressRepository {
  PlanProgressRepository(this._userId);

  final String _userId;

  CollectionReference<Map<String, dynamic>> get _col => FirebaseService
      .firestore
      .collection('users')
      .doc(_userId)
      .collection('plan_progress');

  Stream<PlanProgress> watch(String planId) =>
      _col.doc(planId).snapshots().map(PlanProgress.fromDoc);

  /// Aktif planın kimliği; hiç plan başlatılmadıysa null.
  Stream<String?> watchActivePlanId() =>
      _col.doc(kPlanStateDocId).snapshots().map((doc) {
        final d = doc.data() ?? const <String, dynamic>{};
        final id = d['activePlanId'] as String? ?? '';
        return id.isEmpty ? null : id;
      });

  /// Planı başlatır ve aktif plan yapar. İkinci bir plana başlamak
  /// birincisini duraklatır (silmez — ilerlemesi olduğu yerde durur, kullanıcı
  /// geri dönerse kaldığı yerden devam eder).
  Future<void> start(String planId) async {
    final batch = FirebaseService.firestore.batch();
    batch.set(_col.doc(kPlanStateDocId), {
      'activePlanId': planId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_col.doc(planId), {
      // İlk başlatmada yazılır, sonraki başlatmalarda korunur: "ne zaman
      // başladım" kullanıcının hikâyesidir, her dönüşte sıfırlanmamalı.
      'startedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  /// Bir günü tamamlandı olarak işaretler. arrayUnion: aynı gün iki kez
  /// bitirilse de tek kayıt kalır, iki cihazdan aynı anda yazılsa da
  /// birbirini ezmez.
  Future<void> markDayDone(String planId, String dayId) =>
      _col.doc(planId).set({
        'completedDayIds': FieldValue.arrayUnion([dayId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  /// Planı baştan alır. `startedAt` de sıfırlanır — yeniden başlamak yeni bir
  /// hikâyedir.
  Future<void> reset(String planId) => _col.doc(planId).set({
    'completedDayIds': <String>[],
    'startedAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

// ─── Providers ────────────────────────────────────────────────────────────────

/// Katalog akışı. İçerik herkese açık olduğu için uid'e bağlı değil, ama
/// kurallar `request.auth != null` istiyor — köprü girişi gelmeden açılan
/// stream permission-denied ile ölür ve Firestore stream'i kendini yenilemez
/// (Kural #2'nin nedeni), bu yüzden burada da auth izlenir.
final plansProvider = StreamProvider<List<Plan>>((ref) {
  final fbUid = ref.watch(firebaseAuthUidProvider).valueOrNull;
  if (fbUid == null) return const Stream.empty();
  return PlanCatalogRepository.stream();
});

/// Yalnız gösterilebilir planlar: günü eksik ya da uzunluğu tanımsız plan
/// rafta hiç görünmez (asla sahte/ölü içerik).
final publishablePlansProvider = Provider<List<Plan>>((ref) {
  final plans = ref.watch(plansProvider).valueOrNull ?? const [];
  return plans.where((p) => p.isPublishable).toList();
});

final planProgressRepositoryProvider = Provider<PlanProgressRepository?>((ref) {
  final fbUid = ref.watch(firebaseAuthUidProvider).valueOrNull;
  if (fbUid == null) return null; // köprü girişi bekleniyor
  final auth = ref.watch(authNotifierProvider);
  if (auth is AuthAuthenticated) {
    return PlanProgressRepository(auth.user.id);
  }
  return null;
});

/// Tek bir planın ilerlemesi. Hata/oturumsuz durumda boş ilerleme döner —
/// kullanıcı ekranda hata değil, henüz başlanmamış bir plan görür.
final planProgressProvider = StreamProvider.family<PlanProgress, String>((
  ref,
  planId,
) {
  final repo = ref.watch(planProgressRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.watch(planId);
});

/// Aktif planın kimliği (yoksa null).
final activePlanIdProvider = StreamProvider<String?>((ref) {
  final repo = ref.watch(planProgressRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchActivePlanId();
});

/// Aktif plan — katalog ile ilerleme durumunun kesişimi. Bugün ekranı ve
/// Keşfet rafı buradan beslenir; plan yoksa null.
final activePlanProvider = Provider<Plan?>((ref) {
  final id = ref.watch(activePlanIdProvider).valueOrNull;
  if (id == null) return null;
  final plans = ref.watch(publishablePlansProvider);
  for (final p in plans) {
    if (p.id == id) return p;
  }
  return null;
});
