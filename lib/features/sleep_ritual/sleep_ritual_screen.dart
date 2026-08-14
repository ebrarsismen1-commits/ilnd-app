import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
import 'package:ilnd_app/core/widgets/breath_animation.dart';
import 'package:ilnd_app/core/widgets/breath_ring.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/sleep_ritual/sleep_ritual_models.dart';
import 'package:ilnd_app/features/sleep_ritual/sleep_ritual_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// ILND'nin bu geceye özel kurduğu adım adım gece ritüeli.
class SleepRitualScreen extends ConsumerStatefulWidget {
  const SleepRitualScreen({super.key});

  @override
  ConsumerState<SleepRitualScreen> createState() => _SleepRitualScreenState();
}

class _SleepRitualScreenState extends ConsumerState<SleepRitualScreen> {
  @override
  void initState() {
    super.initState();
    // l10n için context gerekir — ilk kare sonrası planı ILND'ye kurdur.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(sleepRitualFlowProvider.notifier)
          .prepare(AppLocalizations.of(context)!);
    });
  }

  @override
  Widget build(BuildContext context) {
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
            fontSize: 19,
            fontWeight: FontWeight.w300,
            color: p.text,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
      ),
      body: AnimatedBackground(
        palette: p,
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOut,
            child: flow.phase == SleepRitualPhase.running
                ? _RunnerPhase(p: p)
                : _PreparingView(p: p),
          ),
        ),
      ),
    );
  }
}

// ─── Hazırlanıyor ─────────────────────────────────────────────────────────────

class _PreparingView extends StatelessWidget {
  const _PreparingView({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BreathRing(size: 56),
          const SizedBox(height: 24),
          Text(
            l10n.sleepRitualPreparing,
            style: AppTextStyles.body(fontSize: 13, color: p.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─── Koşucu ───────────────────────────────────────────────────────────────────

class _RunnerPhase extends ConsumerWidget {
  const _RunnerPhase({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final flow = ref.watch(sleepRitualFlowProvider);
    final notifier = ref.read(sleepRitualFlowProvider.notifier);
    final step = flow.current;
    if (step == null) return const SizedBox.shrink();

    Future<void> advance() => notifier.advance();

    final Widget body = switch (step.type) {
      SleepRitualStepType.checklist => _ChecklistStep(
        p: p,
        spec: step,
        onContinue: advance,
      ),
      SleepRitualStepType.breath => _BreathStep(
        p: p,
        duration: Duration(seconds: step.breathSeconds),
        onContinue: advance,
      ),
      SleepRitualStepType.text => _TextStep(
        p: p,
        spec: step,
        initialText: flow.answers[flow.index] ?? '',
        onChanged: notifier.setAnswer,
        onContinue: advance,
      ),
      SleepRitualStepType.message => _MessageStep(
        p: p,
        text: step.message,
        onContinue: advance,
      ),
      SleepRitualStepType.closing => _ClosingStep(
        p: p,
        text: step.message,
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
            style: AppTextStyles.label(fontSize: 11.5, color: p.textMuted),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOut,
              child: KeyedSubtree(key: ValueKey(flow.index), child: body),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Nefes alan ikon sahnesi ──────────────────────────────────────────────────

/// Her adımın merkezindeki büyük ikon halkası — marka "nefes" ritmiyle
/// (4sn büyür / 6sn küçülür, BreathRing ile aynı dil) yumuşakça yaşar.
class _StepIconScene extends StatefulWidget {
  const _StepIconScene({
    required this.icon,
    required this.fill,
    required this.iconColor,
  });

  final IconData icon;
  final Color fill;
  final Color iconColor;

  @override
  State<_StepIconScene> createState() => _StepIconSceneState();
}

class _StepIconSceneState extends State<_StepIconScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.94,
        end: 1.06,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 4,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.06,
        end: 0.94,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 6,
    ),
  ]).animate(_c);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 104,
        height: 104,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.fill),
        alignment: Alignment.center,
        child: Icon(widget.icon, size: 42, color: widget.iconColor),
      ),
    );
  }
}

// ─── Adım: kontrol listesi ────────────────────────────────────────────────────

class _ChecklistStep extends ConsumerWidget {
  const _ChecklistStep({
    required this.p,
    required this.spec,
    required this.onContinue,
  });

  final AppPalette p;
  final SleepRitualStepSpec spec;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final flow = ref.watch(sleepRitualFlowProvider);
    final checked = flow.checkedByStep[flow.index] ?? const <int>{};
    final notifier = ref.read(sleepRitualFlowProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Center(
          child: _StepIconScene(
            icon: Icons.self_improvement_rounded,
            fill: p.accentSoft,
            iconColor: p.accent,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          spec.title.isNotEmpty ? spec.title : l10n.sleepRitualStepPrepTitle,
          style: AppTextStyles.display(fontSize: 24, color: p.text),
        ),
        const SizedBox(height: 20),
        for (final (i, label) in spec.items.indexed)
          Pressable(
            onTap: () => notifier.toggleChecklistItem(i),
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
                  Expanded(
                    child: Text(
                      label,
                      style: AppTextStyles.body(fontSize: 15, color: p.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
        BreathAnimation(
          p: p,
          inhaleLabel: l10n.breathPhaseInhale,
          holdLabel: l10n.breathPhaseHold,
          exhaleLabel: l10n.breathPhaseExhale,
        ),
        const SizedBox(height: 32),
        Text(
          done ? '· · ·' : '$mm:$ss',
          style: AppTextStyles.mono(fontSize: 15, color: p.textMuted),
        ),
        const SizedBox(height: 6),
        Text(
          '4 · 4 · 6',
          style: TextStyle(
            fontSize: 11.5,
            color: p.textMuted,
            letterSpacing: 3,
          ),
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

// ─── Adım: yazı ───────────────────────────────────────────────────────────────

class _TextStep extends StatefulWidget {
  const _TextStep({
    required this.p,
    required this.spec,
    required this.initialText,
    required this.onChanged,
    required this.onContinue,
  });

  final AppPalette p;
  final SleepRitualStepSpec spec;
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
        const SizedBox(height: 8),
        Center(
          child: _StepIconScene(
            icon: Icons.edit_note_rounded,
            fill: p.accentSoft,
            iconColor: p.accent,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          widget.spec.prompt,
          style: AppTextStyles.display(fontSize: 24, color: p.text),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: _ctrl,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            style: AppTextStyles.body(fontSize: 15, color: p.text),
            decoration: InputDecoration(
              hintText: widget.spec.hint.isNotEmpty
                  ? widget.spec.hint
                  : l10n.sleepRitualUnloadHint,
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

// ─── Adım: ILND'den mesaj ─────────────────────────────────────────────────────

class _MessageStep extends StatelessWidget {
  const _MessageStep({
    required this.p,
    required this.text,
    required this.onContinue,
  });

  final AppPalette p;
  final String text;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        const Spacer(),
        _StepIconScene(
          icon: Icons.favorite_border_rounded,
          fill: p.accentSoft,
          iconColor: p.accent,
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.display(
              fontSize: 19,
              fontWeight: FontWeight.w400,
              color: p.text,
              height: 1.4,
            ),
          ),
        ),
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

// ─── Adım: kapanış ────────────────────────────────────────────────────────────

class _ClosingStep extends StatelessWidget {
  const _ClosingStep({
    required this.p,
    required this.text,
    required this.onFinish,
  });

  final AppPalette p;
  final String text;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        const Spacer(),
        _StepIconScene(
          icon: Icons.nightlight_round,
          fill: p.amber.withValues(alpha: 0.16),
          iconColor: p.amber,
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.display(
              fontSize: 24,
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
