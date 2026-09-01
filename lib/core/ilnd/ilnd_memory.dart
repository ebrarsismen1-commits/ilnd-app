import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/demo/demo_config.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';

/// Kullanıcının adı yerine prompt'a konan jeton. Gerçek ad hiçbir AI
/// isteğinde cihazdan çıkmaz — model bunu yazar, istemci ekranda değiştirir.
const kNamePlaceholder = '{ad}';

/// Tek bir hafıza notu ve ne zaman düşüldüğü.
///
/// Notlar eskiden düz metindi ve prompt'a yalnız "Son notlar" başlığıyla
/// giriyordu. Model bu yüzden bir haftalık notu bugün olmuş sanıyordu:
/// kullanıcı bir hafta önce erik eklemişti, ILND bugün "sabah yediğin erik"
/// dedi. Notun kendisi doğruydu, zamanı yoktu. O yüzden her not gününü
/// taşır ve prompt'a zaman etiketiyle girer.
class MemoryNote {
  const MemoryNote(this.text, {this.day = ''});

  factory MemoryNote.fromJson(Map<String, dynamic> j) => MemoryNote(
    (j['text'] as String?) ?? '',
    day: (j['day'] as String?) ?? '',
  );

  /// Notun metni (ör. "Yemek: erik (30 kcal)").
  final String text;

  /// Notun düşüldüğü gün, YYYY-MM-DD. Boş dize: tarih bilinmiyor. Bu alan
  /// eklenmeden önce yazılmış kayıtlar böyle okunur; onlara tarih
  /// uydurmuyoruz, "belirsiz" demek yanlış tarihten iyidir.
  final String day;

  DateTime? get date => day.isEmpty ? null : DateTime.tryParse(day);

  /// Prompt'a giren zaman etiketi: "bugün", "dün", "3 gün önce"...
  String ageLabel({DateTime? now}) {
    final at = date;
    if (at == null) return 'tarihi belirsiz';
    final today = DateTime.now();
    final reference = now ?? today;
    final days = DateTime(
      reference.year,
      reference.month,
      reference.day,
    ).difference(DateTime(at.year, at.month, at.day)).inDays;
    if (days <= 0) return 'bugün';
    if (days == 1) return 'dün';
    if (days < 7) return '$days gün önce';
    if (days < 30) return '${days ~/ 7} hafta önce';
    return '${days ~/ 30} ay önce';
  }

  Map<String, dynamic> toJson() => {'text': text, 'day': day};
}

/// ILND'nin kullanıcı hakkında "hatırladıkları".
///
/// Dostluğun temeli budur: her AI etkileşimine bağlam olarak verilir, böylece
/// ILND kullanıcıyı tanıyormuş gibi davranır. Şimdilik lokal (SharedPreferences)
/// tutulur; ileride Supabase/Firestore'a senkronize edilecek (premium: uzun
/// hafıza).
class IlndMemory {
  const IlndMemory({
    this.name = '',
    this.goals = const [],
    this.facts = const [],
    this.recentNotes = const [],
  });

  /// Kullanıcının adı.
  final String name;

  /// Hedefler (ör. "daha düzenli uyumak", "şekeri azaltmak").
  final List<String> goals;

  /// ILND'nin zamanla öğrendiği kalıcı küçük gerçekler
  /// (ör. "vejetaryen", "akşamları stresli").
  final List<String> facts;

  /// Son etkileşimlerden kısa notlar (kayan pencere, en yeni en sonda).
  final List<MemoryNote> recentNotes;

  /// Ücretsiz katmanda hafıza kısa tutulur (maliyet + premium ayrımı).
  static const int freeRecentNotesLimit = 6;

  /// Prompt'a en fazla kaç not gömülür. Saklanan geçmiş bundan uzun olabilir
  /// (premium uzun hafıza); bu sınır **cihazdan çıkan** veriyi bağlar.
  /// Veri minimizasyonu: modele ancak son bağlam için gerekli kadarı gider.
  static const int promptNotesLimit = 6;

  bool get isEmpty =>
      name.isEmpty && goals.isEmpty && facts.isEmpty && recentNotes.isEmpty;

  IlndMemory copyWith({
    String? name,
    List<String>? goals,
    List<String>? facts,
    List<MemoryNote>? recentNotes,
  }) {
    return IlndMemory(
      name: name ?? this.name,
      goals: goals ?? this.goals,
      facts: facts ?? this.facts,
      recentNotes: recentNotes ?? this.recentNotes,
    );
  }

  /// Sistem prompt'una gömülecek insan-okunur özet.
  ///
  /// İki veri minimizasyonu kararı burada uygulanır:
  ///
  /// 1. **Ad gönderilmez.** Yerine [kNamePlaceholder] jetonu konur; model
  ///    jetonu olduğu gibi yazar, istemci cevabı ekrana basmadan önce gerçek
  ///    adla değiştirir (`IlndService.personalize`). Böylece kullanıcının adı
  ///    cihazdan hiç çıkmaz ama ILND ona adıyla hitap etmeye devam eder.
  /// 2. **Not penceresi kırpılır** ([promptNotesLimit]). Saklanan geçmiş daha
  ///    uzun olabilir; dışarı yalnız son notlar gider.
  String toPromptContext({int maxNotes = promptNotesLimit, DateTime? now}) {
    final parts = <String>[];
    if (name.isNotEmpty) parts.add('Adı: $kNamePlaceholder');
    if (goals.isNotEmpty) parts.add('Hedefleri: ${goals.join(', ')}');
    if (facts.isNotEmpty) parts.add('Bildiklerin: ${facts.join('; ')}');
    if (recentNotes.isNotEmpty) {
      final notes = recentNotes.length > maxNotes
          ? recentNotes.sublist(recentNotes.length - maxNotes)
          : recentNotes;
      // Zaman etiketi notun yanından ayrılmaz: modelin elinde tarih yoksa
      // eski bir notu bugüne çekiyor ("sabah yediğin erik").
      final rendered = notes
          .map((n) => '[${n.ageLabel(now: now)}] ${n.text}')
          .join(' | ');
      parts.add(
        'Son notlar (köşeli parantez notun ne zaman düşüldüğünü söyler; o '
        'zamanı olduğu gibi kullan, eski bir notu bugün olmuş gibi anlatma, '
        'tarihi belirsizse ne zaman olduğunu uydurma): $rendered',
      );
    }
    return parts.join('\n');
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'goals': goals,
    'facts': facts,
    'recentNotes': [for (final note in recentNotes) note.toJson()],
  };

  /// Eski kayıtlarda notlar düz metindi; onlar tarihsiz not olarak okunur.
  /// Kullanıcının biriktirdiği hafıza sürüm değiştirdi diye silinmez.
  factory IlndMemory.fromJson(Map<String, dynamic> j) => IlndMemory(
    name: (j['name'] as String?) ?? '',
    goals: List<String>.from((j['goals'] as List?) ?? const []),
    facts: List<String>.from((j['facts'] as List?) ?? const []),
    recentNotes: [
      for (final raw in (j['recentNotes'] as List?) ?? const [])
        if (raw is String)
          MemoryNote(raw)
        else if (raw is Map)
          MemoryNote.fromJson(Map<String, dynamic>.from(raw)),
    ],
  );
}

// ─── Provider ─────────────────────────────────────────────────────────────────

const _kIlndMemory = 'ilnd_memory';

final ilndMemoryProvider =
    StateNotifierProvider<IlndMemoryNotifier, IlndMemory>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      // Onboarding'de girilen ad varsa hafızayı onunla tohumla.
      final seedName = ref.watch(userNameProvider);
      // Hafıza kullanıcıya aittir: uid değişince (çıkış / farklı hesapla
      // giriş) notifier yeniden kurulur ve o kullanıcının anahtarından okur —
      // önceki kullanıcının hafızası yeni kullanıcının AI bağlamına sızmaz.
      // select(uid) sayesinde token yenilemeleri (aynı uid) sıfırlamaz.
      final uid = ref.watch(
        authNotifierProvider.select(
          (s) => s is AuthAuthenticated ? s.user.id : null,
        ),
      );
      return IlndMemoryNotifier(prefs, seedName, uid);
    });

class IlndMemoryNotifier extends StateNotifier<IlndMemory> {
  IlndMemoryNotifier(this._prefs, String seedName, String? uid)
    : _key = uid == null ? _kIlndMemory : '${_kIlndMemory}_$uid',
      super(const IlndMemory()) {
    _load(seedName);
  }

  final dynamic _prefs; // SharedPreferences
  final String _key;

  void _load(String seedName) {
    var raw = _prefs.getString(_key) as String?;
    // Tek-anahtar dönemden geçiş: kullanıcıya özel kayıt yoksa eski global
    // anahtardaki hafızayı bu kullanıcıya taşı (mevcut kullanıcılar
    // güncellemede hafızalarını kaybetmesin), sonra global anahtarı sil.
    if (raw == null && _key != _kIlndMemory) {
      final legacy = _prefs.getString(_kIlndMemory) as String?;
      if (legacy != null && legacy.isNotEmpty) {
        raw = legacy;
        _prefs.setString(_key, legacy);
        _prefs.remove(_kIlndMemory);
      }
    }

    // Demo modu: kayıt yoksa zengin bir kişilikle tohumla ("seni tanıyor").
    if (kDemoMode && (raw == null || raw.isEmpty)) {
      state = kDemoMemory;
      _persist();
      return;
    }

    if (raw != null && raw.isNotEmpty) {
      try {
        state = IlndMemory.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        if (state.name.isEmpty && seedName.isNotEmpty) {
          setName(seedName);
        }
        return;
      } catch (_) {
        // bozuk veri — sıfırdan başla
      }
    }
    if (seedName.isNotEmpty) {
      state = IlndMemory(name: seedName);
      _persist();
    }
  }

  Future<void> _persist() async {
    await _prefs.setString(_key, jsonEncode(state.toJson()));
  }

  Future<void> setName(String name) async {
    state = state.copyWith(name: name);
    await _persist();
  }

  Future<void> addGoal(String goal) async {
    if (goal.trim().isEmpty || state.goals.contains(goal)) return;
    state = state.copyWith(goals: [...state.goals, goal.trim()]);
    await _persist();
  }

  Future<void> addFact(String fact) async {
    if (fact.trim().isEmpty || state.facts.contains(fact)) return;
    state = state.copyWith(facts: [...state.facts, fact.trim()]);
    await _persist();
  }

  /// Yeni bir etkileşim notu ekler; ücretsiz katmanda pencereyi kırpar.
  Future<void> addNote(
    String note, {
    int limit = IlndMemory.freeRecentNotesLimit,
    DateTime? at,
  }) async {
    if (note.trim().isEmpty) return;
    final day = at ?? DateTime.now();
    final notes = [
      ...state.recentNotes,
      MemoryNote(
        note.trim(),
        day:
            '${day.year}-${day.month.toString().padLeft(2, '0')}-'
            '${day.day.toString().padLeft(2, '0')}',
      ),
    ];
    final trimmed = notes.length > limit
        ? notes.sublist(notes.length - limit)
        : notes;
    state = state.copyWith(recentNotes: trimmed);
    await _persist();
  }

  Future<void> clear() async {
    state = const IlndMemory();
    await _persist();
  }
}
