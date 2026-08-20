import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ilnd_app/core/services/firebase_service.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';

import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/ilnd/ilnd_service.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/sleep_ritual/sleep_ritual_models.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

// ─── Akşam penceresi ──────────────────────────────────────────────────────────

/// Ana sayfadaki gece ritüeli daveti yalnız akşam saatlerinde görünür.
/// Saat parametre olarak alınır ki test edilebilsin (_heroImageUrl emsali).
bool isSleepRitualWindow(int hour) => hour >= 21 || hour < 4;

// ─── Bu gece yapıldı bayrağı ──────────────────────────────────────────────────
// İKİ KATMANLI: cihazdaki bayrak "bu gece daveti bir daha gösterme" içindir
// (anlık, ucuz, offline çalışır). Kalıcı kayıt Firestore'a gider —
// `users/{uid}/sleep_rituals/{tarih}`.
//
// Neden ikisi birden: cihaz-yerel bayrak tek başına iki şeyi bozuyordu.
// (1) Kullanıcı telefonu değiştirince ya da web'e geçince yaptığı ritüeller
// yok sayılıyordu — kotada yaşanan hatanın aynı sınıfı (Sert Kural #13).
// (2) Sunucu ritüeli göremediği için "ay ışığı" ada öğesi hiç kazanılamıyordu
// (ADR-0006 §3'te kilitli olarak yazılmıştı).

const _kSleepRitualDate = 'sleep_ritual_date';
const _kSleepRitualDone = 'sleep_ritual_done';

final sleepRitualDoneTonightProvider =
    StateNotifierProvider<SleepRitualDoneTonightNotifier, bool>((ref) {
      return SleepRitualDoneTonightNotifier(
        ref.watch(sharedPreferencesProvider),
      );
    });

class SleepRitualDoneTonightNotifier extends StateNotifier<bool> {
  SleepRitualDoneTonightNotifier(this._prefs) : super(_readIfToday(_prefs));

  final SharedPreferences _prefs;

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static bool _readIfToday(SharedPreferences prefs) {
    if (prefs.getString(_kSleepRitualDate) != _today()) return false;
    return prefs.getBool(_kSleepRitualDone) ?? false;
  }

  /// Cihazdaki bayrağı yazar. Kalıcı kayıt için [recordCompletion] çağrılır.
  Future<void> record() async {
    state = true;
    await _prefs.setString(_kSleepRitualDate, _today());
    await _prefs.setBool(_kSleepRitualDone, true);
  }
}

/// Ritüel tamamlanmasını hesaba yazar — gün başına tek doküman (deterministik
/// id, idempotent). Sessizce başarısız olur: ritüelin kendisi tamamlandı,
/// ağ hatası kullanıcıya bir şey kaybettirmemeli.
Future<void> recordSleepRitualCompletion(Ref ref) async {
  final fbUid = ref.read(firebaseAuthUidProvider).valueOrNull;
  if (fbUid == null) return;
  final now = DateTime.now();
  final date =
      '${now.year}-${now.month.toString().padLeft(2, '0')}'
      '-${now.day.toString().padLeft(2, '0')}';
  try {
    await FirebaseService.firestore
        .collection('users')
        .doc(fbUid)
        .collection('sleep_rituals')
        .doc(date)
        .set({
          'date': date,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  } catch (_) {
    // sessizce yut — bir sonraki ritüelde tekrar denenir
  }
}

// ─── Akış state machine'i ─────────────────────────────────────────────────────

/// autoDispose: ekran kapanınca akış sıfırlanır — yarıda bırakmak hiçbir şey
/// kaydetmez, sonraki açılışta ILND geceyi yeniden kurar (suçluluk yok).
final sleepRitualFlowProvider =
    StateNotifierProvider.autoDispose<
      SleepRitualFlowNotifier,
      SleepRitualFlowState
    >((ref) => SleepRitualFlowNotifier(ref));

class SleepRitualFlowNotifier extends StateNotifier<SleepRitualFlowState> {
  SleepRitualFlowNotifier(this._ref) : super(const SleepRitualFlowState());

  final Ref _ref;

  /// Bu geceye özel planı ILND'ye kurdurur; başarısızlıkta (çevrimdışı,
  /// limit, bozuk yanıt) sabit yedek plana düşer — kullanıcı hata görmez.
  /// Chat deseninde olduğu gibi l10n UI'dan gelir (Sert Kural #1).
  Future<void> prepare(AppLocalizations l10n) async {
    if (state.phase != SleepRitualPhase.idle) return;
    state = state.copyWith(phase: SleepRitualPhase.preparing);

    SleepRitualPlan? plan;
    try {
      final raw = await _ref
          .read(ilndServiceProvider)
          .respond(
            memory: _ref.read(ilndMemoryProvider),
            l10n: l10n,
            tier: IlndTier.quick,
            task:
                'Kullanıcı gece ritüelini açtı: bu geceye özel, adım adım '
                'kısa bir uyku ritüeli kuruyorsun.',
            userMessage:
                'Bu geceye özel 3 ila 5 adımlık bir uyku ritüeli kur. '
                'Hakkımda bildiklerini ve bugünkü notları kullanarak adım '
                'içeriklerini KİŞİSELLEŞTİR; genel geçer olma.\n'
                'Adım tipleri:\n'
                '- "kontrol": 2-4 maddelik hazırlık listesi (baslik + maddeler)\n'
                '- "nefes": rehberli nefes (sure_sn: 60-120)\n'
                '- "yazi": tek cümleyle cevaplanacak sıcak bir soru (soru + ipucu)\n'
                '- "mesaj": bana özel 1-2 cümlelik sıcak bir ara mesaj (metin)\n'
                'Kurallar: en fazla 1 nefes, en fazla 2 yazi; metinler kısa, '
                'küçük harfle, şefkatli; kapanis 1-2 cümlelik iyi geceler '
                'mesajı.\n'
                'Yalnızca şu JSON yapısında yanıt ver, başka hiçbir şey '
                'yazma:\n'
                '{"adimlar":[{"tip":"kontrol","baslik":"...","maddeler":["..."]},'
                '{"tip":"nefes","sure_sn":90},'
                '{"tip":"yazi","soru":"...","ipucu":"..."},'
                '{"tip":"mesaj","metin":"..."}],"kapanis":"..."}',
          );
      if (!mounted) return;
      plan = parseSleepRitualPlan(raw);
    } catch (_) {
      // Sessiz düş: yedek plan aşağıda devreye girer.
    }
    if (!mounted) return;

    plan ??= SleepRitualPlan.fallback(l10n);
    final closing = plan.closing.isNotEmpty
        ? plan.closing
        : sleepRitualClosingFromPool(l10n, DateTime.now().millisecond);

    state = state.copyWith(
      phase: SleepRitualPhase.running,
      queue: [
        ...plan.steps,
        SleepRitualStepSpec(
          type: SleepRitualStepType.closing,
          message: closing,
        ),
      ],
      index: 0,
    );
  }

  void toggleChecklistItem(int item) {
    final step = state.index;
    final next = {for (final e in state.checkedByStep.entries) e.key: e.value};
    final set = {...(next[step] ?? const <int>{})};
    set.contains(item) ? set.remove(item) : set.add(item);
    next[step] = set;
    state = state.copyWith(checkedByStep: next);
  }

  void setAnswer(String text) {
    state = state.copyWith(answers: {...state.answers, state.index: text});
  }

  /// Sıradaki adıma geçer; kapanıştan sonra akışı bitirir: bayrak kaydedilir,
  /// yazı cevapları AI hafızasına not düşer.
  Future<void> advance() async {
    if (state.phase != SleepRitualPhase.running) return;
    if (state.index + 1 < state.queue.length) {
      state = state.copyWith(index: state.index + 1);
      return;
    }

    final notes = <String>[
      for (final e in state.answers.entries)
        if (e.value.trim().isNotEmpty && e.key < state.queue.length)
          'Gece ritüelinde (${state.queue[e.key].prompt}) cevabı: '
              '${e.value.trim()}',
    ];
    state = state.copyWith(phase: SleepRitualPhase.done);

    await _ref.read(sleepRitualDoneTonightProvider.notifier).record();
    if (!mounted) return;
    // Kalıcı kayıt: cihaz değişse de ritüel sayılır, "ay ışığı" ada öğesi
    // sunucudan doğrulanabilir hale gelir.
    await recordSleepRitualCompletion(_ref);
    if (!mounted) return;
    // AI-görünür notlar kanonik TR (desen: mood check-in notu, profile_sync).
    final memory = _ref.read(ilndMemoryProvider.notifier);
    for (final note in notes) {
      await memory.addNote(note);
      if (!mounted) return;
    }
  }
}
