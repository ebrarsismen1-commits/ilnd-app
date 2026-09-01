import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/demo/demo_config.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';

/// Kullanıcının adı yerine prompt'a konan jeton. Gerçek ad hiçbir AI
/// isteğinde cihazdan çıkmaz — model bunu yazar, istemci ekranda değiştirir.
const kNamePlaceholder = '{ad}';

/// Zamanı bilinen bir hafıza notu.
///
/// Notlar eskiden düz metindi ve prompt'a "Son notlar: ..." diye giriyordu.
/// Model iki hafta önce yenen bir eriği dünkünden ayıramıyordu ve
/// "bugün erikler nasıldı" diye soruyordu (2026-08-31'de yaşandı). Sorun
/// modelde değil, ona verilen bağlamdaydı: not zamansızdı ve başlık
/// güncel olduklarını söylüyordu.
class MemoryNote {
  const MemoryNote(this.text, {this.at});

  final String text;

  /// Notun alındığı an. Zaman damgası ÖNCESİNDEN kalan kayıtlarda `null`
  /// olur; tarihi bilinmeyen not eski sayılır.
  final DateTime? at;

  /// [now] gününe göre kaç gün önce. Tarihi yoksa `null`.
  int? ageInDays(DateTime now) {
    final ts = at;
    if (ts == null) return null;
    final a = DateTime(ts.year, ts.month, ts.day);
    final b = DateTime(now.year, now.month, now.day);
    return b.difference(a).inDays;
  }

  /// Prompt'ta notun önüne konan zaman ifadesi.
  String whenLabel(DateTime now) {
    final age = ageInDays(now);
    if (age == null) return 'daha önce';
    if (age <= 0) return 'bugün';
    if (age == 1) return 'dün';
    if (age < 7) return '$age gün önce';
    if (age < 14) return 'geçen hafta';
    return 'birkaç hafta önce';
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    if (at != null) 'at': at!.toIso8601String(),
  };

  /// Eski biçim (düz dize) da okunur: göç sırasında not kaybolmaz, yalnız
  /// tarihsiz kalır.
  static MemoryNote fromJson(Object? raw) {
    if (raw is String) return MemoryNote(raw);
    if (raw is Map) {
      final at = raw['at'];
      return MemoryNote(
        (raw['text'] as String?) ?? '',
        at: at is String ? DateTime.tryParse(at) : null,
      );
    }
    return const MemoryNote('');
  }

  @override
  String toString() => text;
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

  /// Prompt'a girecek notun en fazla kaç günlük olabileceği.
  ///
  /// Bundan eskisi bağlam değil gürültü: kullanıcı iki hafta önceki bir
  /// öğünün bugün konuşulmasını beklemiyor.
  static const int noteFreshnessDays = 14;

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
    final today = now ?? DateTime.now();
    final parts = <String>[];
    if (name.isNotEmpty) parts.add('Adı: $kNamePlaceholder');
    if (goals.isNotEmpty) parts.add('Hedefleri: ${goals.join(', ')}');
    if (facts.isNotEmpty) parts.add('Bildiklerin: ${facts.join('; ')}');

    final fresh = freshNotes(today);
    if (fresh.isNotEmpty) {
      final notes = fresh.length > maxNotes
          ? fresh.sublist(fresh.length - maxNotes)
          : fresh;
      // Her notun önüne ne zaman olduğu yazılır. Eskiden başlık "Son notlar"
      // diyordu ve model hepsini bugüne aitmiş gibi okuyordu: iki hafta
      // önceki bir öğün "bugün" sanılıyordu.
      final rendered = notes
          .map((n) => '${n.whenLabel(today)}: ${n.text}')
          .join(' | ');
      parts.add('Notlar (zamanıyla birlikte): $rendered');
    }
    return parts.join('\n');
  }

  /// Prompt'a girmeye yeterince taze notlar.
  ///
  /// Tarihi bilinmeyen notlar (zaman damgası öncesinden kalanlar) elenir:
  /// ne zaman olduklarını söyleyemiyorsak modele vermek, onun "bugün"
  /// sanmasına yol açıyor.
  List<MemoryNote> freshNotes(DateTime now) => recentNotes.where((n) {
    final age = n.ageInDays(now);
    return age != null && age <= noteFreshnessDays;
  }).toList();

  Map<String, dynamic> toJson() => {
    'name': name,
    'goals': goals,
    'facts': facts,
    'recentNotes': recentNotes.map((n) => n.toJson()).toList(),
  };

  factory IlndMemory.fromJson(Map<String, dynamic> j) => IlndMemory(
    name: (j['name'] as String?) ?? '',
    goals: List<String>.from((j['goals'] as List?) ?? const []),
    facts: List<String>.from((j['facts'] as List?) ?? const []),
    recentNotes: ((j['recentNotes'] as List?) ?? const [])
        .map(MemoryNote.fromJson)
        .where((n) => n.text.isNotEmpty)
        .toList(),
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

  /// Yapısal profilden gelen gerçekleri EKLEMEZ, DEĞİŞTİRİR.
  ///
  /// [addFact] yalnız birebir aynı dizeyi eler. Profil gerçekleri ("Kilo:
  /// 70 kg") güncellendiğinde eskisi de listede kalıyordu, yani ILND aynı
  /// anda iki kiloyu biliyordu. Burada verilen [prefixes] ile başlayan
  /// mevcut gerçekler önce temizlenir.
  ///
  /// Sohbetten öğrenilen gerçekler (ör. "sabahları koşuyor") korunur:
  /// yalnız önekle eşleşenler değiştirilir.
  Future<void> replaceFacts({
    required List<String> prefixes,
    required List<String> facts,
  }) async {
    final kept = state.facts.where((f) => !prefixes.any(f.startsWith)).toList();
    final next = [...kept, ...facts.where((f) => f.trim().isNotEmpty)];
    if (_sameList(next, state.facts)) return;
    state = state.copyWith(facts: next);
    await _persist();
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Yeni bir etkileşim notu ekler; ücretsiz katmanda pencereyi kırpar.
  Future<void> addNote(
    String note, {
    int limit = IlndMemory.freeRecentNotesLimit,
  }) async {
    if (note.trim().isEmpty) return;
    // Zaman damgası ŞART: tarihsiz not prompt'ta "bugün" sanılıyor.
    final notes = [
      ...state.recentNotes,
      MemoryNote(note.trim(), at: DateTime.now()),
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
