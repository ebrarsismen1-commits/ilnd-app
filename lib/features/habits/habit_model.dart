import 'package:cloud_firestore/cloud_firestore.dart';

class Habit {
  const Habit({
    required this.id,
    required this.userId,
    required this.name,
    required this.targetDaysPerWeek,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final int targetDaysPerWeek;
  final DateTime createdAt;

  factory Habit.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Habit(
      id: doc.id,
      userId: d['userId'] as String? ?? '',
      name: d['name'] as String? ?? '',
      targetDaysPerWeek: (d['targetDaysPerWeek'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'name': name,
    'targetDaysPerWeek': targetDaysPerWeek,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
