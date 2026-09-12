import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/breath_ring.dart';
import 'package:ilnd_app/core/widgets/ilnd_surfaces.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

enum _Phase { setup, running, done }

enum _Intent { work, read, own }

enum _Feeling { good, unsure, hard }

/// Odaklan (Ada tasarımı 11-13): hazırlık → seans → tamamlandı.
///
/// Tek ekran, üç hâl: üç ayrı rota kullanıcıyı seansın ortasında geri
/// tuşuyla hazırlığa düşürürdü. Süre bir bitiş anından hesaplanır, saniye
/// saymaz: uygulama arka plana gidip döndüğünde Timer duraklamış olsa bile
/// kalan süre doğru kalır.
///
/// Seans kaydı sunucuya yazılmaz. Tamamlanınca seçilen his, ruh hali
/// kaydıyla aynı yoldan ILND'nin hafızasına not olarak düşer (Bugün'deki
/// mood deseni); başka bir yere gitmeyen bir soru sormuş olmayız.
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  static const _durations = [10, 25, 45];

  _Phase _phase = _Phase.setup;
  _Intent _intent = _Intent.work;
  int _minutes = 25;
  final _ownCtrl = TextEditingController();

  Duration _remaining = Duration.zero;
  DateTime? _endsAt;
  Timer? _ticker;
  int _elapsedMinutes = 0;
  _Feeling? _feeling;

  @override
  void dispose() {
    _ticker?.cancel();
    _ownCtrl.dispose();
    super.dispose();
  }

  String _intentLabel(AppLocalizations l10n) => switch (_intent) {
    _Intent.work => l10n.focusIntentWork,
    _Intent.read => l10n.focusIntentRead,
    _Intent.own =>
      _ownCtrl.text.trim().isEmpty ? l10n.focusIntentOwn : _ownCtrl.text.trim(),
  };

  String _feelingLabel(AppLocalizations l10n, _Feeling f) => switch (f) {
    _Feeling.good => l10n.focusFeelGood,
    _Feeling.unsure => l10n.focusFeelUnsure,
    _Feeling.hard => l10n.focusFeelHard,
  };

  void _start() {
    setState(() {
      _phase = _Phase.running;
      _remaining = Duration(minutes: _minutes);
    });
    _resume();
  }

  void _resume() {
    _endsAt = DateTime.now().add(_remaining);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    setState(() {});
  }

  void _pause() {
    _ticker?.cancel();
    _ticker = null;
    setState(() => _endsAt = null);
  }

  void _tick() {
    final endsAt = _endsAt;
    if (endsAt == null) return;
    final left = endsAt.difference(DateTime.now());
    if (left <= Duration.zero) {
      _finish();
      return;
    }
    setState(() => _remaining = left);
  }

  void _finish() {
    _ticker?.cancel();
    _ticker = null;
    final spent = Duration(minutes: _minutes) - _remaining;
    setState(() {
      // Erken bitirilen seans da sayılır, en az bir dakika: "0 dakika"
      // yazmak kendine ayırdığı ânı küçümsemek olurdu.
      _elapsedMinutes = _remaining <= Duration.zero
          ? _minutes
          : (spent.inSeconds / 60).ceil().clamp(1, _minutes);
      _endsAt = null;
      _phase = _Phase.done;
    });
  }

  void _close(AppLocalizations l10n) {
    final feeling = _feeling;
    if (feeling != null) {
      unawaited(
        ref
            .read(ilndMemoryProvider.notifier)
            .addNote(
              'Odak molası: $_elapsedMinutes dk, ${_intentLabel(l10n)}, '
              '${_feelingLabel(l10n, feeling)}',
            ),
      );
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go(routeHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    return Scaffold(
      backgroundColor: p.base,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              8,
              AppSpacing.screenPadding,
              24,
            ),
            // İçerik kısa telefonda kayar, uzunda buton ekranın dibine
            // oturur: min yükseklik kaydırma alanının kendisi.
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 32,
              ),
              child: IntrinsicHeight(
                child: switch (_phase) {
                  _Phase.setup => _setup(l10n, p),
                  _Phase.running => _running(l10n, p),
                  _Phase.done => _done(l10n, p),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _setup(AppLocalizations l10n, AppPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IlndPageHeader(
          p: p,
          title: l10n.focusTitle,
          subtitle: l10n.focusSubtitle,
        ),
        const SizedBox(height: 20),
        IslandFrame(p: p, height: 150, radius: AppSpacing.radius + 4),
        const SizedBox(height: 24),
        Text(
          l10n.focusIntentLabel,
          style: AppTextStyles.serifTitle(color: p.text),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final intent in _Intent.values)
              IlndChip(
                p: p,
                label: switch (intent) {
                  _Intent.work => l10n.focusIntentWork,
                  _Intent.read => l10n.focusIntentRead,
                  _Intent.own => l10n.focusIntentOwn,
                },
                selected: _intent == intent,
                onTap: () => setState(() => _intent = intent),
              ),
          ],
        ),
        if (_intent == _Intent.own) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _ownCtrl,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            style: AppTextStyles.body(fontSize: 14.5, color: p.text),
            decoration: InputDecoration(
              hintText: l10n.focusIntentHint,
              counterText: '',
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          l10n.focusDurationLabel,
          style: AppTextStyles.serifTitle(color: p.text),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in _durations)
              IlndChip(
                p: p,
                label: l10n.focusMinutes(m),
                selected: _minutes == m,
                onTap: () => setState(() => _minutes = m),
              ),
          ],
        ),
        const SizedBox(height: 28),
        const Spacer(),
        IlndButton(p: p, label: l10n.focusStart, onTap: _start),
        const SizedBox(height: 14),
        Center(
          child: Text(
            l10n.focusNote,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(fontSize: 12, color: p.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _running(AppLocalizations l10n, AppPalette p) {
    final total = Duration(minutes: _minutes).inSeconds;
    final progress = total == 0
        ? 0.0
        : (1 - _remaining.inSeconds / total).clamp(0.0, 1.0);
    final mm = _remaining.inMinutes.toString().padLeft(2, '0');
    final ss = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    final time = '$mm:$ss';
    final paused = _endsAt == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(
          _intentLabel(l10n).toUpperCase(),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption(color: p.textMuted),
        ),
        const SizedBox(height: 16),
        IslandFrame(p: p, height: 200),
        const SizedBox(height: 28),
        Semantics(
          label: l10n.a11yFocusTimeLeft(time),
          excludeSemantics: true,
          child: Text(
            time,
            textAlign: TextAlign.center,
            style: AppTextStyles.mono(
              fontSize: 42,
              color: p.text,
            ).copyWith(letterSpacing: -1),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.focusSessionMeta(_minutes),
          textAlign: TextAlign.center,
          style: AppTextStyles.body(fontSize: 13, color: p.textMuted),
        ),
        const SizedBox(height: 18),
        Center(
          child: SizedBox(
            width: 200,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: p.border,
                color: p.accent,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Spacer(),
        IlndButton(
          p: p,
          label: paused ? l10n.focusResume : l10n.focusPause,
          onTap: paused ? _resume : _pause,
        ),
        const SizedBox(height: 10),
        IlndButton(
          p: p,
          kind: IlndButtonKind.secondary,
          label: l10n.focusEnd,
          onTap: _finish,
        ),
        const SizedBox(height: 14),
        Text(
          l10n.focusSessionFooter,
          textAlign: TextAlign.center,
          style: AppTextStyles.body(fontSize: 12, color: p.textMuted),
        ),
      ],
    );
  }

  Widget _done(AppLocalizations l10n, AppPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        const Center(child: BreathRing(size: 64)),
        const SizedBox(height: 22),
        Text(
          l10n.focusDoneTitle,
          textAlign: TextAlign.center,
          style: AppTextStyles.pageTitle(color: p.text, fontSize: 25),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.focusDoneMeta(_elapsedMinutes, _intentLabel(l10n)),
          textAlign: TextAlign.center,
          style: AppTextStyles.body(fontSize: 13, color: p.textMuted),
        ),
        const SizedBox(height: 32),
        Text(
          l10n.focusFeelQuestion,
          style: AppTextStyles.serifTitle(color: p.text),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in _Feeling.values)
              IlndChip(
                p: p,
                label: _feelingLabel(l10n, f),
                selected: _feeling == f,
                onTap: () =>
                    setState(() => _feeling = _feeling == f ? null : f),
              ),
          ],
        ),
        const SizedBox(height: 28),
        const Spacer(),
        IlndButton(
          p: p,
          label: l10n.focusBackToToday,
          onTap: () => _close(l10n),
        ),
        const SizedBox(height: 14),
        Text(
          l10n.focusDoneFooter,
          textAlign: TextAlign.center,
          style: AppTextStyles.body(fontSize: 12, color: p.textMuted),
        ),
      ],
    );
  }
}
