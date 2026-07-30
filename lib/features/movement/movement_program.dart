import 'package:cloud_firestore/cloud_firestore.dart';

/// Programın zorluk tonu. İsimler bilerek spor-salonu dili değil ILND dili:
/// "başlangıç/ileri" seviye hiyerarşisi kurar, "yumuşak/güçlü" ise bedenin o
/// günkü hâlini tarif eder (non-preachy tonu — bkz. PROJECT_PRINCIPLES).
enum MovementLevel { easy, medium, strong }

extension MovementLevelX on MovementLevel {
  String get firestoreValue => name;

  static MovementLevel fromString(String s) => MovementLevel.values.firstWhere(
    (e) => e.name == s,
    orElse: () => MovementLevel.easy,
  );
}

/// Bir programın tek seansı — bir video.
class MovementSession {
  const MovementSession({
    required this.id,
    required this.title,
    required this.videoUrl,
    this.minutes = 0,
    this.thumbnailUrl,
  });

  /// Program içinde sabit kimlik: ilerleme kaydı bu id'ye yazılır, bu yüzden
  /// içerik güncellenirken DEĞİŞTİRİLMEZ (değişirse kullanıcının tamamladığı
  /// seans yeniden "yapılmamış" görünür).
  final String id;
  final String title;

  /// Firebase Storage'daki video (indirme URL'i). Boşsa seans oynatılamaz —
  /// UI böyle bir seansı hiç göstermez (asla ölü dokunuş).
  final String videoUrl;
  final int minutes;
  final String? thumbnailUrl;

  bool get isPlayable => videoUrl.isNotEmpty;

  factory MovementSession.fromMap(Map<String, dynamic> m) => MovementSession(
    id: m['id'] as String? ?? '',
    title: m['title'] as String? ?? '',
    videoUrl: m['videoUrl'] as String? ?? '',
    minutes: (m['minutes'] as num?)?.toInt() ?? 0,
    thumbnailUrl: m['thumbnailUrl'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'videoUrl': videoUrl,
    'minutes': minutes,
    'thumbnailUrl': thumbnailUrl,
  };

  MovementSession copyWith({String? title}) => MovementSession(
    id: id,
    title: title ?? this.title,
    videoUrl: videoUrl,
    minutes: minutes,
    thumbnailUrl: thumbnailUrl,
  );
}

/// Bir programın İngilizce karşılığı — boş alanlar Türkçesine düşer
/// (ArticleTranslation emsali: EN kullanıcı asla boş ekran görmez).
class MovementTranslation {
  const MovementTranslation({
    this.title = '',
    this.description = '',
    this.sessionTitles = const {},
  });

  final String title;
  final String description;

  /// seans id → İngilizce başlık. Liste değil map: seans sırası değişse bile
  /// çeviri doğru seansa bağlı kalır.
  final Map<String, String> sessionTitles;

  factory MovementTranslation.fromMap(Map<String, dynamic> m) =>
      MovementTranslation(
        title: m['title'] as String? ?? '',
        description: m['description'] as String? ?? '',
        sessionTitles: {
          for (final e in ((m['sessionTitles'] as Map?) ?? const {}).entries)
            '${e.key}': '${e.value}',
        },
      );

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'sessionTitles': sessionTitles,
  };
}

/// Video tabanlı hareket programı (ADR-0004).
///
/// İçerik `content/movementPrograms.json` + `seedMovementPrograms.js` ile
/// `movement_programs` koleksiyonuna yazılır; istemci yalnız okur.
class MovementProgram {
  const MovementProgram({
    required this.id,
    required this.title,
    this.description = '',
    this.level = MovementLevel.easy,
    this.sessions = const [],
    this.coverUrl,
    this.order = 0,
    this.premium = false,
    this.en,
  });

  final String id;
  final String title;
  final String description;
  final MovementLevel level;
  final List<MovementSession> sessions;
  final String? coverUrl;
  final int order;

  /// ILND+ üyeliğine kilitli mi. Hangi programın kilitli olacağı içerik
  /// kararıdır (JSON'dan gelir), kod kararı değil.
  final bool premium;

  final MovementTranslation? en;

  /// Oynatılabilir seansı olmayan program gösterilmez: yarım yüklenmiş bir
  /// içerik, kullanıcıya boş bir vaat olarak çıkmamalı.
  bool get isPublishable => playableSessions.isNotEmpty;

  List<MovementSession> get playableSessions =>
      sessions.where((s) => s.isPlayable).toList();

  int get totalMinutes => playableSessions.fold(0, (acc, s) => acc + s.minutes);

  /// Uygulama diline göre sürüm. Alan bazında düşer: çeviride eksik kalan
  /// alan Türkçesiyle tamamlanır.
  MovementProgram forLocale(String localeCode) {
    final t = en;
    if (!localeCode.startsWith('en') || t == null) return this;
    return MovementProgram(
      id: id,
      title: t.title.isNotEmpty ? t.title : title,
      description: t.description.isNotEmpty ? t.description : description,
      level: level,
      sessions: [
        for (final s in sessions)
          s.copyWith(
            title: (t.sessionTitles[s.id] ?? '').isNotEmpty
                ? t.sessionTitles[s.id]
                : s.title,
          ),
      ],
      coverUrl: coverUrl,
      order: order,
      premium: premium,
      en: t,
    );
  }

  factory MovementProgram.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? const {};
    return MovementProgram(
      id: doc.id,
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      level: MovementLevelX.fromString(d['level'] as String? ?? ''),
      sessions: [
        for (final s in (d['sessions'] as List? ?? const []))
          if (s is Map) MovementSession.fromMap(Map<String, dynamic>.from(s)),
      ],
      coverUrl: d['coverUrl'] as String?,
      order: (d['order'] as num?)?.toInt() ?? 0,
      premium: d['premium'] as bool? ?? false,
      en: d['en'] is Map
          ? MovementTranslation.fromMap(
              Map<String, dynamic>.from(d['en'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'level': level.firestoreValue,
    'sessions': [for (final s in sessions) s.toMap()],
    'coverUrl': coverUrl,
    'order': order,
    'premium': premium,
    if (en != null) 'en': en!.toMap(),
  };
}

/// Kullanıcının bir programdaki ilerlemesi:
/// `users/{uid}/movement_progress/{programId}` dokümanı.
class MovementProgress {
  const MovementProgress({this.completedSessionIds = const {}});

  final Set<String> completedSessionIds;

  bool isDone(String sessionId) => completedSessionIds.contains(sessionId);

  int doneCountIn(MovementProgram program) => program.playableSessions
      .where((s) => completedSessionIds.contains(s.id))
      .length;

  bool isComplete(MovementProgram program) =>
      program.isPublishable &&
      doneCountIn(program) == program.playableSessions.length;

  /// Sıradaki seans: tamamlanmamış ilk seans. Hepsi bittiyse baştan başlar
  /// (program tekrar izlenebilir — "yeniden izle").
  MovementSession? nextSession(MovementProgram program) {
    final playable = program.playableSessions;
    if (playable.isEmpty) return null;
    for (final s in playable) {
      if (!completedSessionIds.contains(s.id)) return s;
    }
    return playable.first;
  }

  factory MovementProgress.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? const {};
    return MovementProgress(
      completedSessionIds: {
        for (final s in (d['completedSessionIds'] as List? ?? const [])) '$s',
      },
    );
  }
}
