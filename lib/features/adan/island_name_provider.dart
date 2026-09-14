import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/services/firebase_service.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';

const islandNameMaxLength = 32;

String normalizeIslandName(String value) =>
    value.replaceAll(RegExp(r'\s+'), ' ').trim();

bool isValidIslandName(String value) {
  final name = normalizeIslandName(value);
  return name.isNotEmpty &&
      name.characters.length <= islandNameMaxLength &&
      !RegExp(r'[\x00-\x1F\x7F]').hasMatch(name);
}

/// Both sessions must identify the same account before personal data is read.
final islandNameAccountProvider = Provider<String?>((ref) {
  final uid = ref.watch(firebaseAuthUidProvider).valueOrNull;
  if (uid == null) return null;
  final auth = ref.watch(authNotifierProvider);
  return auth is AuthAuthenticated && auth.user.id == uid ? uid : null;
});

abstract interface class IslandNameStore {
  Stream<String?> watch(String uid);
  Future<void> save(String uid, String name);
}

class FirestoreIslandNameStore implements IslandNameStore {
  DocumentReference<Map<String, dynamic>> _document(String uid) =>
      FirebaseService.firestore
          .collection('users')
          .doc(uid)
          .collection('preferences')
          .doc('island');

  @override
  Stream<String?> watch(String uid) =>
      _document(uid).snapshots().map((snapshot) {
        final raw = snapshot.data()?['name'];
        return raw is String && isValidIslandName(raw)
            ? normalizeIslandName(raw)
            : null;
      });

  @override
  Future<void> save(String uid, String name) => _document(uid)
      .set({
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true))
      .timeout(const Duration(seconds: 15));
}

final islandNameStoreProvider = Provider<IslandNameStore>(
  (ref) => FirestoreIslandNameStore(),
);

final _nameForAccountProvider = StreamProvider.autoDispose
    .family<String?, String>(
      (ref, uid) => ref.watch(islandNameStoreProvider).watch(uid),
    );

/// Account-keyed stream prevents a previous account's name during refresh.
final islandNameProvider = Provider<AsyncValue<String?>>((ref) {
  final uid = ref.watch(islandNameAccountProvider);
  return uid == null
      ? const AsyncData(null)
      : ref.watch(_nameForAccountProvider(uid));
});

final saveIslandNameProvider = Provider<Future<void> Function(String)>((ref) {
  final uid = ref.watch(islandNameAccountProvider);
  final store = ref.watch(islandNameStoreProvider);
  var currentUid = uid;
  ref.listen<String?>(islandNameAccountProvider, (_, next) {
    currentUid = next;
  });
  ref.onDispose(() {
    currentUid = null;
  });
  return (value) async {
    if (!isValidIslandName(value)) throw ArgumentError('Invalid island name');
    if (uid == null || currentUid != uid) {
      throw StateError('Account changed or session unavailable');
    }
    // Personal preference only. Server-awarded island/{uid} remains read-only.
    await store.save(uid, normalizeIslandName(value));
  };
});

void refreshIslandName(WidgetRef ref) {
  final uid = ref.read(islandNameAccountProvider);
  if (uid != null) ref.invalidate(_nameForAccountProvider(uid));
}
