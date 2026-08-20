import 'package:cloud_firestore/cloud_firestore.dart';

/// Bir plan basamağının uzunluğu. 30 değil 7/14/21: ilk zaferi bir haftada
/// vermek tamamlanma oranı lehine (ADR-0005).
const Set<int> kPlanLengths = {7, 14, 21};

/// Planın gününe iliştirilen tek eylem. "Tek gün = tek adım" bilinçli:
/// üç adımlı gün, günü yarım bırakma olasılığını üçe katlıyordu (ADR-0005,
/// elenen alternatif 3).
enum PlanAction { none, breath, move, water, journal }

extension PlanActionX on PlanAction {
  String get firestoreValue => name;

  static PlanAction fromString(String s) => PlanAction.values.firstWhere(
    (e) => e.name == s,
    orElse: () => PlanAction.none,
  );
}

/// Planın bir günü.
class PlanDay {
  const PlanDay({
    required this.id,
    required this.title,
    this.articleId = '',
    this.action = PlanAction.none,
    this.note = '',
  });

  /// Plan içinde sabit kimlik: ilerleme kaydı bu id'ye yazılır, bu yüzden
  /// içerik güncellenirken DEĞİŞTİRİLMEZ (değişirse kullanıcının bitirdiği
  /// gün yeniden "yapılmamış" görünür — MovementSession.id ile aynı gerekçe).
  final String id;
  final String title;

  /// Günün okuması: `articles` koleksiyonundaki bir makale. Boş olabilir —
  /// o gün yalnızca bir eylemden ibaret olabilir.
  final String articleId;
  final PlanAction action;

  /// Günün tek cümlelik yönlendirmesi. İçerik metnidir, `.arb`'de değil
  /// (makale gövdesiyle aynı statü — Sert Kural #1 arayüz metni içindir).
  final String note;

  /// Ne okuma ne eylem taşıyan gün, kullanıcıya boş bir gün olarak çıkar.
  bool get hasContent => articleId.isNotEmpty || action != PlanAction.none;

  factory PlanDay.fromMap(Map<String, dynamic> m) => PlanDay(
    id: m['id'] as String? ?? '',
    title: m['title'] as String? ?? '',
    articleId: m['articleId'] as String? ?? '',
    action: PlanActionX.fromString(m['action'] as String? ?? ''),
    note: m['note'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'articleId': articleId,
    'action': action.firestoreValue,
    'note': note,
  };

  PlanDay copyWith({String? title, String? note}) => PlanDay(
    id: id,
    title: title ?? this.title,
    articleId: articleId,
    action: action,
    note: note ?? this.note,
  );
}

/// Planın İngilizce karşılığı — boş alanlar Türkçesine düşer
/// (ArticleTranslation/MovementTranslation emsali: EN kullanıcı asla boş
/// ekran görmez).
class PlanTranslation {
  const PlanTranslation({
    this.title = '',
    this.description = '',
    this.dayTitles = const {},
    this.dayNotes = const {},
  });

  final String title;
  final String description;

  /// gün id → İngilizce başlık/not. Liste değil map: gün sırası değişse bile
  /// çeviri doğru güne bağlı kalır.
  final Map<String, String> dayTitles;
  final Map<String, String> dayNotes;

  static Map<String, String> _stringMap(Object? raw) => {
    for (final e in ((raw as Map?) ?? const {}).entries)
      '${e.key}': '${e.value}',
  };

  factory PlanTranslation.fromMap(Map<String, dynamic> m) => PlanTranslation(
    title: m['title'] as String? ?? '',
    description: m['description'] as String? ?? '',
    dayTitles: _stringMap(m['dayTitles']),
    dayNotes: _stringMap(m['dayNotes']),
  );

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'dayTitles': dayTitles,
    'dayNotes': dayNotes,
  };
}

/// Rehberli plan (ADR-0005).
///
/// İçerik `content/plans.json` + `seedPlans.js` ile `plans` koleksiyonuna
/// yazılır; istemci yalnız okur (`allow write: if false`).
class Plan {
  const Plan({
    required this.id,
    required this.title,
    this.description = '',
    this.days = const [],
    this.coverUrl,
    this.order = 0,
    this.premium = false,
    this.en,
  });

  final String id;
  final String title;
  final String description;
  final List<PlanDay> days;
  final String? coverUrl;
  final int order;

  /// ILND+ üyeliğine kilitli mi. Hangi planın kilitli olacağı içerik
  /// kararıdır (JSON'dan gelir), kod kararı değil — 7 günlük giriş basamağı
  /// ücretsiz kalır, 14 ve 21 kilitlenir (ADR-0005).
  ///
  /// Not: bu alan yalnız *gösterim* kararıdır. Erişim kapısı tek noktadadır
  /// (`hasPremiumAccessProvider`); ikinci bir premium kontrolü yazılmaz.
  final bool premium;

  final PlanTranslation? en;

  int get lengthDays => days.length;

  /// Yarım yüklenmiş plan kullanıcıya boş vaat olarak çıkmamalı: uzunluğu
  /// tanımlı basamaklardan biri olmayan ya da içi boş günü bulunan plan hiç
  /// gösterilmez (ADR-0004'teki `isPublishable` ilkesinin aynısı).
  bool get isPublishable =>
      kPlanLengths.contains(days.length) && days.every((d) => d.hasContent);

  /// Uygulama diline göre sürüm. Alan bazında düşer: çeviride eksik kalan
  /// alan Türkçesiyle tamamlanır.
  Plan forLocale(String localeCode) {
    final t = en;
    if (!localeCode.startsWith('en') || t == null) return this;
    return Plan(
      id: id,
      title: t.title.isNotEmpty ? t.title : title,
      description: t.description.isNotEmpty ? t.description : description,
      days: [
        for (final d in days)
          d.copyWith(
            title: (t.dayTitles[d.id] ?? '').isNotEmpty
                ? t.dayTitles[d.id]
                : d.title,
            note: (t.dayNotes[d.id] ?? '').isNotEmpty
                ? t.dayNotes[d.id]
                : d.note,
          ),
      ],
      coverUrl: coverUrl,
      order: order,
      premium: premium,
      en: t,
    );
  }

  factory Plan.fromDoc(DocumentSnapshot doc) =>
      Plan.fromMap(doc.id, doc.data() as Map<String, dynamic>? ?? const {});

  /// Firestore'dan bağımsız kurucu: `content/plans.json` de aynı şekli
  /// taşıdığı için içerik dosyası ağ olmadan doğrulanabilir
  /// (test/features/plans/plans_content_test.dart).
  factory Plan.fromMap(String id, Map<String, dynamic> d) {
    return Plan(
      id: id,
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      days: [
        for (final day in (d['days'] as List? ?? const []))
          if (day is Map) PlanDay.fromMap(Map<String, dynamic>.from(day)),
      ],
      coverUrl: d['coverUrl'] as String?,
      order: (d['order'] as num?)?.toInt() ?? 0,
      premium: d['premium'] as bool? ?? false,
      en: d['en'] is Map
          ? PlanTranslation.fromMap(Map<String, dynamic>.from(d['en'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'days': [for (final d in days) d.toMap()],
    'coverUrl': coverUrl,
    'order': order,
    'premium': premium,
    if (en != null) 'en': en!.toMap(),
  };
}

/// Kullanıcının bir plandaki ilerlemesi:
/// `users/{uid}/plan_progress/{planId}` dokümanı.
///
/// Bu bir ÖVÜNÇ verisidir, hak verisi değil: kullanıcı yazabildiği için
/// premium hakkı buraya asla bakmaz (Sert Kural #13'ün mantığı).
class PlanProgress {
  const PlanProgress({this.completedDayIds = const {}, this.startedAt});

  final Set<String> completedDayIds;
  final DateTime? startedAt;

  bool get isStarted => startedAt != null || completedDayIds.isNotEmpty;

  bool isDone(String dayId) => completedDayIds.contains(dayId);

  int doneCountIn(Plan plan) =>
      plan.days.where((d) => completedDayIds.contains(d.id)).length;

  bool isComplete(Plan plan) =>
      plan.isPublishable && doneCountIn(plan) == plan.days.length;

  /// 0.0–1.0. Boş planda 0 — sıfıra bölme yok.
  double ratioIn(Plan plan) =>
      plan.days.isEmpty ? 0 : doneCountIn(plan) / plan.days.length;

  /// Sıradaki gün: tamamlanmamış ilk gün. Hepsi bittiyse null döner —
  /// hareket programının aksine plan baştan başlatılmaz, "bitti" bir sondur
  /// (bitiş kartı orada üretilir).
  PlanDay? nextDay(Plan plan) {
    for (final d in plan.days) {
      if (!completedDayIds.contains(d.id)) return d;
    }
    return null;
  }

  factory PlanProgress.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? const {};
    final started = d['startedAt'];
    return PlanProgress(
      completedDayIds: {
        for (final id in (d['completedDayIds'] as List? ?? const [])) '$id',
      },
      startedAt: started is Timestamp ? started.toDate() : null,
    );
  }
}
