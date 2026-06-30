import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/ilnd/ilnd_fallbacks.dart';
import 'package:ilnd_app/core/ilnd/ilnd_learner.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/ilnd/ilnd_service.dart';
import 'package:ilnd_app/core/repositories/journal_repository.dart';
import 'package:ilnd_app/core/repositories/referral_repository.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/services/analytics_service.dart';
import 'package:ilnd_app/core/services/onboarding_timer.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

enum _Phase { writing, reflecting, response }

/// Onboarding'in son adımı — auth'tan hemen sonra gösterilir. İlk günlük
/// yazısını yakalar (time-to-first-value ölçümü burada biter). Asla zorunlu
/// değil: "şimdi değil" ile atlanabilir.
class FirstEntryScreen extends ConsumerStatefulWidget {
  const FirstEntryScreen({super.key});

  @override
  ConsumerState<FirstEntryScreen> createState() => _FirstEntryScreenState();
}

class _FirstEntryScreenState extends ConsumerState<FirstEntryScreen> {
  final _controller = TextEditingController();
  _Phase _phase = _Phase.writing;
  String _ilndReply = '';

  @override
  void initState() {
    super.initState();
    unawaited(_redeemPendingReferralCode());
    Future.microtask(
      () => ref.read(currentOnboardingStepProvider.notifier).state = (
        2,
        'first_entry',
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _redeemPendingReferralCode() async {
    final code = ref.read(referralCodeInputProvider);
    if (code == null || code.isEmpty) return;
    final repo = ref.read(referralRepositoryProvider);
    if (repo == null) return;
    final redeemed = await repo.redeemCode(code);
    if (redeemed) {
      unawaited(AnalyticsService.logReferralSignupCompleted());
      unawaited(AnalyticsService.logReferralRewardClaimed());
    }
    await ref.read(referralCodeInputProvider.notifier).clear();
  }

  Future<void> _finish() async {
    await ref.read(firstEntryDoneProvider.notifier).setDone();
    ref.read(currentOnboardingStepProvider.notifier).state = null;
    final elapsed = OnboardingTimer.elapsed();
    if (elapsed != null) {
      unawaited(AnalyticsService.logTimeToFirstValue(elapsed));
    }
    OnboardingTimer.reset();
    if (mounted) context.go(routeHome);
  }

  Future<void> _skip() async {
    unawaited(AnalyticsService.logEvent('onboarding_first_entry_skipped'));
    await _finish();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      await _skip();
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();
    setState(() => _phase = _Phase.reflecting);

    final memory = ref.read(ilndMemoryProvider);
    final service = ref.read(ilndServiceProvider);

    String reply;
    try {
      reply = await service.respond(
        memory: memory,
        userMessage: 'Günlüğüme şunu yazdım:\n$text',
        task:
            'Kullanıcının ilk günlük yazısına yargısız, sıcak ve kısa bir karşılık ver. '
            'Önce duygusunu karşıla, sonra düşünmeye davet eden tek nazik bir '
            'soru sor. Liste yapma, 2-3 cümleyi geçme.',
        tier: IlndTier.deep,
        fallback: IlndFallbacks.journal(l10n),
        l10n: l10n,
      );
    } catch (e) {
      reply = IlndService.friendlyError(e, l10n);
    }

    final repo = ref.read(journalRepositoryProvider);
    if (repo != null) {
      unawaited(
        repo.add(
          JournalEntry(
            id: '',
            body: text,
            ilndReply: reply,
            createdAt: DateTime.now(),
          ),
        ),
      );
    }

    await ref
        .read(ilndMemoryProvider.notifier)
        .addNote(
          'Günlük: ${text.length > 80 ? '${text.substring(0, 80)}…' : text}',
        );
    unawaited(ref.read(ilndLearnerProvider).learnFrom(text, l10n));

    if (mounted) {
      setState(() {
        _ilndReply = reply;
        _phase = _Phase.response;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    return Scaffold(
      backgroundColor: p.base,
      body: AnimatedBackground(
        palette: p,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.firstEntryHeader,
                      style: AppTextStyles.sectionLabel(color: p.textMuted),
                    ),
                    if (_phase == _Phase.writing)
                      Pressable(
                        onTap: _skip,
                        child: Text(
                          l10n.firstEntrySkip,
                          style: AppTextStyles.body(
                            fontSize: 13,
                            color: p.textMuted,
                          ).copyWith(decoration: TextDecoration.underline),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _phase == _Phase.response
                    ? _ResponseView(
                        reply: _ilndReply,
                        entry: _controller.text,
                        p: p,
                      )
                    : _WritingView(controller: _controller, p: p),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
                child: Pressable(
                  onTap: _phase == _Phase.reflecting
                      ? null
                      : (_phase == _Phase.response ? _finish : _save),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: _phase == _Phase.reflecting
                          ? p.accent.withValues(alpha: 0.5)
                          : p.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: _phase == _Phase.reflecting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: p.onAccent,
                            ),
                          )
                        : Text(
                            _phase == _Phase.response
                                ? l10n.firstEntryReady
                                : l10n.firstEntrySave,
                            style: AppTextStyles.body(
                              fontSize: 15,
                              color: p.onAccent,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WritingView extends StatelessWidget {
  const _WritingView({required this.controller, required this.p});
  final TextEditingController controller;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.firstEntryPrompt,
            style: AppTextStyles.display(fontSize: 26, color: p.text),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              maxLines: null,
              expands: true,
              textCapitalization: TextCapitalization.sentences,
              style: AppTextStyles.display(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: p.text,
                height: 1.55,
              ),
              decoration: InputDecoration(
                hintText: l10n.firstEntryHint,
                hintStyle: AppTextStyles.display(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: p.textMuted.withValues(alpha: 0.7),
                  height: 1.55,
                ),
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponseView extends StatelessWidget {
  const _ResponseView({
    required this.reply,
    required this.entry,
    required this.p,
  });
  final String reply;
  final String entry;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry,
            style: AppTextStyles.display(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: p.textMuted,
              height: 1.5,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radius),
              border: Border.all(color: p.border, width: 0.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: p.accent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'i',
                    style: AppTextStyles.display(
                      fontSize: 15,
                      color: p.onAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    reply,
                    style: AppTextStyles.body(
                      fontSize: 15,
                      height: 1.5,
                      color: p.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
