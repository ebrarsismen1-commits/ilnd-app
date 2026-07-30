import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/services/firebase_service.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/features/movement/movement_program.dart';

/// Hareket programı kataloğu (ADR-0004) — herkese aynı, salt okunur içerik.
class MovementCatalogRepository {
  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseService.firestore.collection('movement_programs');

  static Stream<List<MovementProgram>> stream() => _col
      .orderBy('order')
      .snapshots()
      .map((s) => s.docs.map(MovementProgram.fromDoc).toList());
}

/// Kullanıcının program ilerlemesi — `users/{uid}/movement_progress/{programId}`.
///
/// Kota/hak değil ilerleme olduğu için istemci yazabilir (Sert Kural #13
/// yalnız sınır/kota içindir); yer users/{uid} altı olduğundan mevcut
/// sahiplik kuralı yeterli, ayrı rule gerekmez.
class MovementProgressRepository {
  MovementProgressRepository(this._userId);

  final String _userId;

  CollectionReference<Map<String, dynamic>> get _col => FirebaseService
      .firestore
      .collection('users')
      .doc(_userId)
      .collection('movement_progress');

  Stream<MovementProgress> watch(String programId) =>
      _col.doc(programId).snapshots().map(MovementProgress.fromDoc);

  /// Bir seansı tamamlandı olarak işaretler. arrayUnion: aynı seans iki kez
  /// bitirilse de tek kayıt kalır, iki cihazdan aynı anda yazılsa da
  /// birbirini ezmez.
  Future<void> markSessionDone(String programId, String sessionId) =>
      _col.doc(programId).set({
        'completedSessionIds': FieldValue.arrayUnion([sessionId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  /// "Yeniden izle": program baştan alınır.
  Future<void> reset(String programId) => _col.doc(programId).set({
    'completedSessionIds': <String>[],
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

// ─── Providers ────────────────────────────────────────────────────────────────

/// Katalog akışı. İçerik herkese açık olduğu için uid'e bağlı değil, ama
/// kurallar `request.auth != null` istiyor — köprü girişi gelmeden açılan
/// stream permission-denied ile ölür ve Firestore stream'i kendini yenilemez
/// (Kural #2'nin nedeni), bu yüzden burada da auth izlenir.
final movementProgramsProvider = StreamProvider<List<MovementProgram>>((ref) {
  final fbUid = ref.watch(firebaseAuthUidProvider).valueOrNull;
  if (fbUid == null) return const Stream.empty();
  return MovementCatalogRepository.stream();
});

/// Yalnız gösterilebilir programlar: oynatılabilir seansı olmayan program
/// rafta hiç görünmez (asla sahte/ölü içerik).
final publishableMovementProgramsProvider = Provider<List<MovementProgram>>((
  ref,
) {
  final programs = ref.watch(movementProgramsProvider).valueOrNull ?? const [];
  return programs.where((p) => p.isPublishable).toList();
});

final movementProgressRepositoryProvider =
    Provider<MovementProgressRepository?>((ref) {
      final fbUid = ref.watch(firebaseAuthUidProvider).valueOrNull;
      if (fbUid == null) return null; // köprü girişi bekleniyor
      final auth = ref.watch(authNotifierProvider);
      if (auth is AuthAuthenticated) {
        return MovementProgressRepository(auth.user.id);
      }
      return null;
    });

/// Tek bir programın ilerlemesi. Hata/oturumsuz durumda boş ilerleme döner —
/// kullanıcı ekranda hata değil, henüz başlanmamış bir program görür.
final movementProgressProvider =
    StreamProvider.family<MovementProgress, String>((ref, programId) {
      final repo = ref.watch(movementProgressRepositoryProvider);
      if (repo == null) return const Stream.empty();
      return repo.watch(programId);
    });
