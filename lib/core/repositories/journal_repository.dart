import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/services/firebase_service.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.body,
    required this.ilndReply,
    required this.createdAt,
  });

  final String id;
  final String body;
  final String ilndReply;
  final DateTime createdAt;

  factory JournalEntry.fromDoc(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return JournalEntry(
      id: doc.id,
      body: data['body'] as String? ?? '',
      ilndReply: data['ilndReply'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap(String userId) => {
        'userId': userId,
        'body': body,
        'ilndReply': ilndReply,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

// ─── Repository ───────────────────────────────────────────────────────────────

class JournalRepository {
  JournalRepository(this._userId);

  final String _userId;

  CollectionReference<Map<String, dynamic>> get _col => FirebaseService.firestore
      .collection('users')
      .doc(_userId)
      .collection('journal_entries');

  Stream<List<JournalEntry>> stream() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(JournalEntry.fromDoc).toList());

  Future<void> add(JournalEntry entry) =>
      _col.add(entry.toMap(_userId));
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final journalRepositoryProvider = Provider<JournalRepository?>((ref) {
  final auth = ref.watch(authNotifierProvider);
  if (auth is AuthAuthenticated) {
    return JournalRepository(auth.user.id);
  }
  return null;
});

final journalEntriesProvider = StreamProvider<List<JournalEntry>>((ref) {
  final repo = ref.watch(journalRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.stream();
});
