import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/demo/demo_config.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';

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
  final List<String> recentNotes;

  /// Ücretsiz katmanda hafıza kısa tutulur (maliyet + premium ayrımı).
  static const int freeRecentNotesLimit = 6;

  bool get isEmpty =>
      name.isEmpty && goals.isEmpty && facts.isEmpty && recentNotes.isEmpty;

  IlndMemory copyWith({
    String? name,
    List<String>? goals,
    List<String>? facts,
    List<String>? recentNotes,
  }) {
    return IlndMemory(
      name: name ?? this.name,
      goals: goals ?? this.goals,
      facts: facts ?? this.facts,
      recentNotes: recentNotes ?? this.recentNotes,
    );
  }

  /// Sistem prompt'una gömülecek insan-okunur özet.
  String toPromptContext() {
    final parts = <String>[];
    if (name.isNotEmpty) parts.add('Adı: $name');
    if (goals.isNotEmpty) parts.add('Hedefleri: ${goals.join(', ')}');
    if (facts.isNotEmpty) parts.add('Bildiklerin: ${facts.join('; ')}');
    if (recentNotes.isNotEmpty) {
      parts.add('Son notlar: ${recentNotes.join(' | ')}');
    }
    return parts.join('\n');
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'goals': goals,
    'facts': facts,
    'recentNotes': recentNotes,
  };

  factory IlndMemory.fromJson(Map<String, dynamic> j) => IlndMemory(
    name: (j['name'] as String?) ?? '',
    goals: List<String>.from((j['goals'] as List?) ?? const []),
    facts: List<String>.from((j['facts'] as List?) ?? const []),
    recentNotes: List<String>.from((j['recentNotes'] as List?) ?? const []),
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
  }) async {
    if (note.trim().isEmpty) return;
    final notes = [...state.recentNotes, note.trim()];
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
