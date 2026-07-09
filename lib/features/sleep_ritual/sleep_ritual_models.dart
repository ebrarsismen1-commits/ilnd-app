/// Uyku ritüelinin adımları. [closing] seçilemez — her akışın sonuna
/// otomatik eklenir (kapanış her zaman dahil).
enum SleepRitualStep { prep, breath, unload, gratitude, closing }

/// Seçim ekranında sunulan adımlar, akıştaki sabit sırasıyla.
const kSleepRitualSelectableSteps = [
  SleepRitualStep.prep,
  SleepRitualStep.breath,
  SleepRitualStep.unload,
  SleepRitualStep.gratitude,
];

/// Kapanış mesajı havuzunun boyu (sleepRitualClosing1..N l10n anahtarları).
const kSleepRitualClosingCount = 4;

/// Hazırlık kontrol listesindeki madde sayısı (ışıklar / telefon / yatak).
const kSleepRitualPrepItemCount = 3;

enum SleepRitualPhase { picker, running, done }

/// Akışın tamamı tek immutable state: seçim ekranı → koşucu → bitti.
class SleepRitualFlowState {
  const SleepRitualFlowState({
    this.phase = SleepRitualPhase.picker,
    this.selected = const {},
    this.queue = const [],
    this.index = 0,
    this.prepChecked = const {},
    this.unloadText = '',
    this.gratitudeText = '',
    this.closingIndex = 0,
  });

  final SleepRitualPhase phase;

  /// Seçim ekranında işaretlenen adımlar.
  final Set<SleepRitualStep> selected;

  /// start() anında kurulan sıralı akış (son eleman her zaman [closing]).
  final List<SleepRitualStep> queue;
  final int index;

  /// Hazırlık adımında işaretlenen madde indeksleri (0..2).
  final Set<int> prepChecked;

  /// Yazı adımlarının içerikleri — controller'lar widget'ta, metin burada.
  final String unloadText;
  final String gratitudeText;

  /// Kapanış mesajı havuzundan bu gece için seçilen indeks (0-tabanlı).
  final int closingIndex;

  SleepRitualStep? get current =>
      (phase == SleepRitualPhase.running && index < queue.length)
      ? queue[index]
      : null;

  bool get canStart => selected.isNotEmpty;

  SleepRitualFlowState copyWith({
    SleepRitualPhase? phase,
    Set<SleepRitualStep>? selected,
    List<SleepRitualStep>? queue,
    int? index,
    Set<int>? prepChecked,
    String? unloadText,
    String? gratitudeText,
    int? closingIndex,
  }) {
    return SleepRitualFlowState(
      phase: phase ?? this.phase,
      selected: selected ?? this.selected,
      queue: queue ?? this.queue,
      index: index ?? this.index,
      prepChecked: prepChecked ?? this.prepChecked,
      unloadText: unloadText ?? this.unloadText,
      gratitudeText: gratitudeText ?? this.gratitudeText,
      closingIndex: closingIndex ?? this.closingIndex,
    );
  }
}
