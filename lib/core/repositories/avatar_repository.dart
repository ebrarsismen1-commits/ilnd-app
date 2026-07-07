import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/services/firebase_service.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';

/// Profil fotoğrafı — küçültülmüş resim `users/{uid}` dokümanında base64 olarak
/// tutulur (Storage paketi/bucket kurulumu gerektirmez, cihazlar arası taşınır).
/// Resim UI'da 512px'e küçültülüp sıkıştırıldığı için doküman 1MB sınırının
/// çok altında kalır.
class AvatarRepository {
  AvatarRepository(this._uid);

  final String _uid;

  DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseService.firestore.collection('users').doc(_uid);

  Stream<String?> stream() => _doc.snapshots().map((d) {
    // Sert Kural #3: doc.data()! yasak.
    final data = d.data() ?? const <String, dynamic>{};
    final v = data['photoBase64'] as String?;
    return (v == null || v.isEmpty) ? null : v;
  });

  Future<void> save(String base64) async {
    await _doc.set({
      'photoBase64': base64,
      'photoUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> remove() async {
    await _doc.set({'photoBase64': null}, SetOptions(merge: true));
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

/// Kullanıcıya bağlı: hem köprü uid'ini hem auth'u izler (Sert Kural #2) ki
/// köprü girişi gelmeden stream açıp permission-denied ile ölmesin.
final avatarRepositoryProvider = Provider<AvatarRepository?>((ref) {
  final fbUid = ref.watch(firebaseAuthUidProvider).valueOrNull;
  if (fbUid == null) return null; // köprü girişi bekleniyor
  final auth = ref.watch(authNotifierProvider);
  if (auth is! AuthAuthenticated) return null;
  return AvatarRepository(auth.user.id);
});

/// Base64 profil fotoğrafı (yoksa null).
final userAvatarProvider = StreamProvider<String?>((ref) {
  final repo = ref.watch(avatarRepositoryProvider);
  if (repo == null) return const Stream<String?>.empty();
  return repo.stream();
});
