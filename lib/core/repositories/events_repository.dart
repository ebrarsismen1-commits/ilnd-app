import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/services/firebase_service.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';

/// Topluluk etkinliği (ADR-0002). İçerik yalnız seed script'ten gelir;
/// client `events`e asla yazmaz — RSVP alt koleksiyonu tek yazma yüzeyidir.
class CommunityEvent {
  const CommunityEvent({
    required this.id,
    required this.title,
    required this.city,
    required this.venue,
    required this.startsAt,
    this.capacity,
  });

  final String id;
  final String title;
  final String city;
  final String venue;
  final DateTime startsAt;
  final int? capacity;

  factory CommunityEvent.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? const {};
    return CommunityEvent(
      id: doc.id,
      title: d['title'] as String? ?? '',
      city: d['city'] as String? ?? '',
      venue: d['venue'] as String? ?? '',
      startsAt: (d['startsAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      capacity: (d['capacity'] as num?)?.toInt(),
    );
  }
}

class EventsRepository {
  EventsRepository(this._userId);
  final String _userId;

  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseService.firestore.collection('events');

  /// Yaklaşan etkinlikler — geçmişler listeden düşer.
  Stream<List<CommunityEvent>> upcoming() => _col
      .where('startsAt', isGreaterThanOrEqualTo: Timestamp.now())
      .orderBy('startsAt')
      .limit(20)
      .snapshots()
      .map((s) => s.docs.map(CommunityEvent.fromDoc).toList());

  DocumentReference<Map<String, dynamic>> _myRsvp(String eventId) =>
      _col.doc(eventId).collection('rsvps').doc(_userId);

  /// Kullanıcının bu etkinliğe RSVP durumu (canlı).
  Stream<bool> myRsvpStream(String eventId) =>
      _myRsvp(eventId).snapshots().map((d) => d.exists);

  /// Katılımcı sayısı — aggregate count(), doküman okumaz.
  Future<int> rsvpCount(String eventId) async {
    final agg = await _col.doc(eventId).collection('rsvps').count().get();
    return agg.count ?? 0;
  }

  Future<void> rsvp(String eventId) => _myRsvp(
    eventId,
  ).set({'userId': _userId, 'createdAt': FieldValue.serverTimestamp()});

  Future<void> cancelRsvp(String eventId) => _myRsvp(eventId).delete();
}

// ─── Providers ────────────────────────────────────────────────────────────────

final eventsRepositoryProvider = Provider<EventsRepository?>((ref) {
  final fbUid = ref.watch(firebaseAuthUidProvider).valueOrNull;
  if (fbUid == null) return null; // köprü girişi bekleniyor
  final auth = ref.watch(authNotifierProvider);
  if (auth is AuthAuthenticated) return EventsRepository(auth.user.id);
  return null;
});

final upcomingEventsProvider = StreamProvider<List<CommunityEvent>>((ref) {
  final repo = ref.watch(eventsRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.upcoming();
});

/// Etkinlik başına RSVP durumum (canlı) — family ile etkinliğe bağlanır.
/// autoDispose: kart ekrandan kalkınca Firestore dinleyicisi kapanır —
/// aksi halde her görülen etkinliğin dinleyicisi oturum boyunca açık kalır
/// (sızıntı; etkinlik sayısı arttıkça birikir).
final myRsvpProvider = StreamProvider.autoDispose.family<bool, String>((
  ref,
  eventId,
) {
  final repo = ref.watch(eventsRepositoryProvider);
  if (repo == null) return Stream.value(false);
  return repo.myRsvpStream(eventId);
});

/// Etkinlik başına katılımcı sayısı. RSVP durumum değişince yenilenir
/// (kendi katılımım sayıya anında yansısın diye myRsvpProvider izlenir).
final rsvpCountProvider = FutureProvider.autoDispose.family<int, String>((
  ref,
  eventId,
) {
  ref.watch(myRsvpProvider(eventId));
  final repo = ref.watch(eventsRepositoryProvider);
  if (repo == null) return Future.value(0);
  return repo.rsvpCount(eventId);
});
