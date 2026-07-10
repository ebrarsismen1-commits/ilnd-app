import 'dart:convert';
import 'dart:math';

import 'package:ilnd_app/core/ilnd/ai_json.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Kapanış mesajı havuzunun boyu (sleepRitualClosing1..N l10n anahtarları) —
/// AI kapanış üretmediğinde/yedek akışta kullanılır.
const kSleepRitualClosingCount = 4;

/// Bir ritüel adımının tipi. Ritüeli ILND kurar; UI bu tiplere göre çizer.
enum SleepRitualStepType {
  /// Tik'lenebilir hazırlık listesi (ışıkları kıs...).
  checklist,

  /// Süreli rehberli nefes (BreathAnimation).
  breath,

  /// Tek satırlık yazı istemi (günü boşalt, güzel an...).
  text,

  /// ILND'den sıcak bir ara mesaj — sadece okunur, devam edilir.
  message,

  /// Kapanış: iyi geceler mesajı + bitir. Her akışın son adımı.
  closing,
}

/// Tek bir adımın içeriği — alanlar tipe göre dolar, gerisi boş kalır.
class SleepRitualStepSpec {
  const SleepRitualStepSpec({
    required this.type,
    this.title = '',
    this.items = const [],
    this.prompt = '',
    this.hint = '',
    this.message = '',
    this.breathSeconds = 112,
  });

  final SleepRitualStepType type;
  final String title; // checklist başlığı
  final List<String> items; // checklist maddeleri
  final String prompt; // text sorusu
  final String hint; // text alan ipucu
  final String message; // message/closing metni
  final int breathSeconds;
}

/// ILND'nin (veya yedeğin) kurduğu gece planı. [steps] kapanışı İÇERMEZ;
/// koşucu kuyruğun sonuna kapanışı kendisi ekler.
class SleepRitualPlan {
  const SleepRitualPlan({required this.steps, required this.closing});

  final List<SleepRitualStepSpec> steps;
  final String closing;

  /// AI'sız/çevrimdışı yedek: sabit ama eksiksiz bir gece akışı. Kullanıcı
  /// hata görmez, ritüel her koşulda çalışır.
  factory SleepRitualPlan.fallback(AppLocalizations l10n, {Random? random}) {
    final r = random ?? Random();
    return SleepRitualPlan(
      steps: [
        SleepRitualStepSpec(
          type: SleepRitualStepType.checklist,
          title: l10n.sleepRitualStepPrepTitle,
          items: [
            l10n.sleepRitualPrepItemLights,
            l10n.sleepRitualPrepItemPhone,
            l10n.sleepRitualPrepItemBed,
          ],
        ),
        const SleepRitualStepSpec(type: SleepRitualStepType.breath),
        SleepRitualStepSpec(
          type: SleepRitualStepType.text,
          prompt: l10n.sleepRitualUnloadPrompt,
          hint: l10n.sleepRitualUnloadHint,
        ),
        SleepRitualStepSpec(
          type: SleepRitualStepType.text,
          prompt: l10n.sleepRitualGratitudePrompt,
          hint: l10n.sleepRitualGratitudeHint,
        ),
      ],
      closing: sleepRitualClosingFromPool(l10n, r.nextInt(1 << 16)),
    );
  }
}

/// Kapanış havuzundan deterministik seçim (index mod havuz boyu).
String sleepRitualClosingFromPool(AppLocalizations l10n, int index) =>
    switch (index % kSleepRitualClosingCount) {
      0 => l10n.sleepRitualClosing1,
      1 => l10n.sleepRitualClosing2,
      2 => l10n.sleepRitualClosing3,
      _ => l10n.sleepRitualClosing4,
    };

/// ILND'nin JSON yanıtını plana çevirir; şema bozuksa null (yedeğe düşülür).
/// Beklenen yapı:
/// {"adimlar":[{"tip":"kontrol","baslik":"...","maddeler":["..."]},
///             {"tip":"nefes","sure_sn":90},
///             {"tip":"yazi","soru":"...","ipucu":"..."},
///             {"tip":"mesaj","metin":"..."}],
///  "kapanis":"..."}
SleepRitualPlan? parseSleepRitualPlan(String rawText) {
  try {
    final raw = extractJsonObject(rawText);
    if (raw == null) return null;
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    final rawSteps = (parsed['adimlar'] as List?) ?? const [];

    final steps = <SleepRitualStepSpec>[];
    var breathCount = 0;
    for (final s in rawSteps) {
      if (s is! Map) continue;
      final m = Map<String, dynamic>.from(s);
      String str(String k) => (m[k] as String?)?.trim() ?? '';
      switch (str('tip')) {
        case 'kontrol':
          final items = ((m['maddeler'] as List?) ?? const [])
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .take(4)
              .toList();
          if (items.isEmpty) continue;
          steps.add(
            SleepRitualStepSpec(
              type: SleepRitualStepType.checklist,
              title: str('baslik'),
              items: items,
            ),
          );
        case 'nefes':
          if (breathCount > 0) continue; // en fazla 1 nefes adımı
          breathCount++;
          final sn = (m['sure_sn'] as num?)?.toInt() ?? 90;
          steps.add(
            SleepRitualStepSpec(
              type: SleepRitualStepType.breath,
              breathSeconds: sn.clamp(30, 180),
            ),
          );
        case 'yazi':
          final prompt = str('soru');
          if (prompt.isEmpty) continue;
          steps.add(
            SleepRitualStepSpec(
              type: SleepRitualStepType.text,
              prompt: prompt,
              hint: str('ipucu'),
            ),
          );
        case 'mesaj':
          final text = str('metin');
          if (text.isEmpty) continue;
          steps.add(
            SleepRitualStepSpec(
              type: SleepRitualStepType.message,
              message: text,
            ),
          );
      }
      if (steps.length == 5) break;
    }

    if (steps.isEmpty) return null;
    return SleepRitualPlan(
      steps: steps,
      closing: (parsed['kapanis'] as String?)?.trim() ?? '',
    );
  } catch (_) {
    return null;
  }
}

enum SleepRitualPhase { idle, preparing, running, done }

/// Akışın tamamı tek immutable state: hazırlanıyor → adımlar → bitti.
class SleepRitualFlowState {
  const SleepRitualFlowState({
    this.phase = SleepRitualPhase.idle,
    this.queue = const [],
    this.index = 0,
    this.checkedByStep = const {},
    this.answers = const {},
  });

  final SleepRitualPhase phase;

  /// Koşulacak adımlar — son eleman her zaman [SleepRitualStepType.closing].
  final List<SleepRitualStepSpec> queue;
  final int index;

  /// Checklist adımlarında işaretlenen maddeler (adım indexi → madde seti).
  final Map<int, Set<int>> checkedByStep;

  /// Yazı adımlarının cevapları (adım indexi → metin).
  final Map<int, String> answers;

  SleepRitualStepSpec? get current =>
      (phase == SleepRitualPhase.running && index < queue.length)
      ? queue[index]
      : null;

  SleepRitualFlowState copyWith({
    SleepRitualPhase? phase,
    List<SleepRitualStepSpec>? queue,
    int? index,
    Map<int, Set<int>>? checkedByStep,
    Map<int, String>? answers,
  }) {
    return SleepRitualFlowState(
      phase: phase ?? this.phase,
      queue: queue ?? this.queue,
      index: index ?? this.index,
      checkedByStep: checkedByStep ?? this.checkedByStep,
      answers: answers ?? this.answers,
    );
  }
}
