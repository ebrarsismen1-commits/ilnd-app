import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
import 'package:ilnd_app/core/widgets/breath_animation.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/sleep_ritual/sleep_ritual_models.dart';
import 'package:ilnd_app/features/sleep_ritual/sleep_ritual_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Adım adım gece ritüeli: seçim ekranı → seçilen adımlar → kapanış.
class SleepRitualScreen extends ConsumerWidget {
  const SleepRitualScreen({
    super.key,
    this.breathDuration = const Duration(seconds: 112), // 8 × 14sn döngü
  });

  /// Nefes adımının süresi — testte kısa süre enjekte edilir.
  final Duration breathDuration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final flow = ref.watch(sleepRitualFlowProvider);

    return Scaffold(
      backgroundColor: p.base,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: p.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.sleepRitualTitle,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w300,
            color: p.text,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: false,
      body: AnimatedBackground(
        palette: p,
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOut,
            child: flow.phase == SleepRitualPhase.picker
                ? _PickerPhase(p: p)
                : _RunnerPhase(p: p, breathDuration: breathDuration),
          ),
        ),
      ),
    );
  }
}

// ─── Seçim ekranı ─────────────────────────────────────────────────────────────

class _PickerPhase extends ConsumerWidget {
  const _PickerPhase({required this.p});
  final AppPalette p;

  (String, String) _copy(AppLocalizations l10n, SleepRitualStep s) =>
      switch (s) {
        SleepRitualStep.prep => (
          l10n.sleepRitualStepPrepTitle,
          l10n.sleepRitualStepPrepSubtitle,
        ),
        SleepRitualStep.breath => (
          l10n.sleepRitualStepBreathTitle,
          l10n.sleepRitualStepBreathSubtitle,
        ),
        SleepRitualStep.unload => (
          l10n.sleepRitualStepUnloadTitle,
          l10n.sleepRitualStepUnloadSubtitle,
        ),
        SleepRitualStep.gratitude => (
          l10n.sleepRitualStepGratitudeTitle,
          l10n.sleepRitualStepGratitudeSubtitle,
        ),
        SleepRitualStep.closing => ('', ''),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final flow = ref.watch(sleepRitualFlowProvider);
    final notifier = ref.read(sleepRitualFlowProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Entrance(
            index: 0,
            child: Text(
              l10n.sleepRitualPickerHeading,
              style: AppTextStyles.display(fontSize: 26, color: p.text),
            ),
          ),
          const SizedBox(height: 20),
          for (final (i, step) in kSleepRitualSelectableSteps.indexed) ...[
            Entrance(
              index: i + 1,
              child: _PickerCard(
                p: p,
                title: _copy(l10n, step).$1,
                subtitle: _copy(l10n, step).$2,
                selected: flow.selected.contains(step),
                onTap: () => notifier.toggleStep(step),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          Entrance(
            index: 5,
            child: Text(
              l10n.sleepRitualPickerClosingNote,
              style: AppTextStyles.body(fontSize: 12.5, color: p.textMuted),
            ),
          ),
          const Spacer(),
          Entrance(
            index: 6,
            child: _PrimaryButton(
              p: p,
              label: l10n.sleepRitualStartButton,
              enabled: flow.canStart,
              onTap: notifier.start,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _PickerCard extends StatelessWidget {
  const _PickerCard({
    required this.p,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final AppPalette p;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? p.accent : p.border,
            width: selected ? 1.4 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 20,
              color: selected ? p.accent : p.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.heading(fontSize: 15, color: p.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.body(
                      fontSize: 12.5,
                      color: p.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Koşucu ───────────────────────────────────────────────────────────────────

class _RunnerPhase extends ConsumerWidget {
  const _RunnerPhase({required this.p, required this.breathDuration});
  final AppPalette p;
  final Duration breathDuration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final flow = ref.watch(sleepRitualFlowProvider);
    final notifier = ref.read(sleepRitualFlowProvider.notifier);
    final step = flow.current;
    if (step == null) return const SizedBox.shrink();

    Future<void> advance() => notifier.advance();

    final Widget body = switch (step) {
      SleepRitualStep.prep => _PrepStep(p: p, onContinue: advance),
      SleepRitualStep.breath => _BreathStep(
        p: p,
        duration: breathDuration,
        onContinue: advance,
      ),
      SleepRitualStep.unload => _TextStep(
        key: const ValueKey('unload'),
        p: p,
        prompt: l10n.sleepRitualUnloadPrompt,
        hint: l10n.sleepRitualUnloadHint,
        initialText: flow.unloadText,
        onChanged: notifier.setUnloadText,
        onContinue: advance,
      ),
      SleepRitualStep.gratitude => _TextStep(
        key: const ValueKey('gratitude'),
        p: p,
        prompt: l10n.sleepRitualGratitudePrompt,
        hint: l10n.sleepRitualGratitudeHint,
        initialText: flow.gratitudeText,
        onChanged: notifier.setGratitudeText,
        onContinue: advance,
      ),
      SleepRitualStep.closing => _ClosingStep(
        p: p,
        closingIndex: flow.closingIndex,
        onFinish: () async {
          await advance();
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            l10n.sleepRitualStepProgress(flow.index + 1, flow.queue.length),
            style: AppTextStyles.label(fontSize: 11, color: p.textMuted),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOut,
              child: KeyedSubtree(key: ValueKey(step), child: body),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Adım: hazırlık ───────────────────────────────────────────────────────────

class _PrepStep extends ConsumerWidget {
  const _PrepStep({required this.p, required this.onContinue});
  final AppPalette p;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final checked = ref.watch(
      sleepRitualFlowProvider.select((s) => s.prepChecked),
    );
    final notifier = ref.read(sleepRitualFlowProvider.notifier);
    final items = [
      l10n.sleepRitualPrepItemLights,
      l10n.sleepRitualPrepItemPhone,
      l10n.sleepRitualPrepItemBed,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.sleepRitualStepPrepTitle,
          style: AppTextStyles.display(fontSize: 24, color: p.text),
        ),
        const SizedBox(height: 20),
        for (final (i, label) in items.indexed) ...[
          Pressable(
            onTap: () => notifier.togglePrepItem(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(
                    checked.contains(i)
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 22,
                    color: checked.contains(i) ? p.accent : p.textMuted,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: AppTextStyles.body(fontSize: 15, color: p.text),
                  ),
                ],
              ),
            ),
          ),
        ],
        const Spacer(),
        _PrimaryButton(
          p: p,
          label: l10n.sleepRitualContinueButton,
          enabled: true,
          onTap: onContinue,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ─── Adım: nefes ──────────────────────────────────────────────────────────────

class _BreathStep extends StatefulWidget {
  const _BreathStep({
    required this.p,
    required this.duration,
    required this.onContinue,
  });

  final AppPalette p;
  final Duration duration;
  final VoidCallback onContinue;

  @override
  State<_BreathStep> createState() => _BreathStepState();
}

class _BreathStepState extends State<_BreathStep> {
  late int _remaining = widget.duration.inSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 0) {
        t.cancel();
        return;
      }
      setState(() => _remaining--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get _elapsed => widget.duration.inSeconds - _remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = widget.p;
    final done = _remaining <= 0;
    // İlk 14 sn'lik döngü tamamlanmadan geç linki gösterilmez — kimse
    // tuzağa düşmesin ama ilk nefes de yarıda kesilmesin.
    final showSkip = !done && _elapsed >= 14;
    final mm = (_remaining ~/ 60).toString();
    final ss = (_remaining % 60).toString().padLeft(2, '0');

    return Column(
      children: [
        const Spacer(),
        BreathAnimation(p: p),
        const SizedBox(height: 32),
        Text(
          done ? '· · ·' : '$mm:$ss',
          style: AppTextStyles.mono(fontSize: 15, color: p.textMuted),
        ),
        const SizedBox(height: 6),
        Text(
          '4 · 4 · 6',
          style: TextStyle(fontSize: 12, color: p.textMuted, letterSpacing: 3),
        ),
        const Spacer(),
        _PrimaryButton(
          p: p,
          label: l10n.sleepRitualContinueButton,
          enabled: done,
          onTap: widget.onContinue,
        ),
        SizedBox(
          height: 40,
          child: showSkip
              ? Center(
                  child: Pressable(
                    onTap: widget.onContinue,
                    child: Text(
                      l10n.sleepRitualSkipButton,
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: p.textMuted,
                      ),
                    ),
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

// ─── Adım: yazı (günü boşalt / güzel an) ──────────────────────────────────────

class _TextStep extends StatefulWidget {
  const _TextStep({
    super.key,
    required this.p,
    required this.prompt,
    required this.hint,
    required this.initialText,
    required this.onChanged,
    required this.onContinue,
  });

  final AppPalette p;
  final String prompt;
  final String hint;
  final String initialText;
  final ValueChanged<String> onChanged;
  final VoidCallback onContinue;

  @override
  State<_TextStep> createState() => _TextStepState();
}

class _TextStepState extends State<_TextStep> {
  late final _ctrl = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = widget.p;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.prompt,
          style: AppTextStyles.display(fontSize: 22, color: p.text),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.border, width: 0.5),
          ),
          child: TextField(
            controller: _ctrl,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            style: AppTextStyles.body(fontSize: 15, color: p.text),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: AppTextStyles.body(fontSize: 15, color: p.textMuted),
              border: InputBorder.none,
            ),
            onChanged: widget.onChanged,
            onSubmitted: (_) => widget.onContinue(),
          ),
        ),
        const Spacer(),
        _PrimaryButton(
          p: p,
          label: l10n.sleepRitualContinueButton,
          enabled: true,
          onTap: widget.onContinue,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ─── Adım: kapanış ────────────────────────────────────────────────────────────

class _ClosingStep extends StatelessWidget {
  const _ClosingStep({
    required this.p,
    required this.closingIndex,
    required this.onFinish,
  });

  final AppPalette p;
  final int closingIndex;
  final VoidCallback onFinish;

  String _message(AppLocalizations l10n) => switch (closingIndex % 4) {
    0 => l10n.sleepRitualClosing1,
    1 => l10n.sleepRitualClosing2,
    2 => l10n.sleepRitualClosing3,
    _ => l10n.sleepRitualClosing4,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        const Spacer(),
        Text('🌙', style: TextStyle(fontSize: 34, color: p.amber)),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            _message(l10n),
            textAlign: TextAlign.center,
            style: AppTextStyles.display(
              fontSize: 22,
              fontWeight: FontWeight.w400,
              color: p.text,
              height: 1.4,
            ),
          ),
        ),
        const Spacer(),
        _PrimaryButton(
          p: p,
          label: l10n.sleepRitualFinishButton,
          enabled: true,
          onTap: onFinish,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ─── Ortak birincil buton ─────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.p,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final AppPalette p;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          color: enabled ? p.accent : p.accent.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.body(
            fontSize: 15,
            color: p.onAccent,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
