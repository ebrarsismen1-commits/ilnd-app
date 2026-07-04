import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/ilnd/ilnd_fallbacks.dart';
import 'package:ilnd_app/core/ilnd/ilnd_learner.dart';
import 'package:ilnd_app/core/ilnd/crisis_guard.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/ilnd/ilnd_service.dart';
import 'package:ilnd_app/core/repositories/journal_repository.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/core/widgets/shimmer.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

// ─── Screen ──────────────────────────────────────────────────────────────────

class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final entriesAsync = ref.watch(journalEntriesProvider);

    return Scaffold(
      backgroundColor: p.base,
      body: AnimatedBackground(
        palette: p,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    28,
                    AppSpacing.screenPadding,
                    0,
                  ),
                  child: Text(
                    l10n.journalTitle,
                    style: AppTextStyles.display(fontSize: 32, color: p.text),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    20,
                    AppSpacing.screenPadding,
                    0,
                  ),
                  child: _NewEntryButton(
                    p: p,
                    onTap: () => _showWriteSheet(context, ref),
                  ),
                ),
              ),
              entriesAsync.when(
                loading: () => SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    20,
                    AppSpacing.screenPadding,
                    0,
                  ),
                  sliver: SliverList.separated(
                    itemCount: 4,
                    separatorBuilder: (ctx1, i1) => const SizedBox(height: 12),
                    itemBuilder: (ctx1, i1) => const ShimmerCard(),
                  ),
                ),
                error: (e, st) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ErrorState(
                    p: p,
                    onRetry: () => ref.invalidate(journalEntriesProvider),
                  ),
                ),
                data: (entries) => entries.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyJournal(
                          p: p,
                          onTap: () => _showWriteSheet(context, ref),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenPadding,
                          20,
                          AppSpacing.screenPadding,
                          32,
                        ),
                        sliver: SliverList.separated(
                          itemCount: entries.length,
                          separatorBuilder: (ctx2, i2) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) => Entrance(
                            index: i,
                            child: _EntryCard(entry: entries[i], p: p),
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

// ─── Error state ─────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.p, required this.onRetry});
  final dynamic p;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🔌', style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 16),
          Text(
            l10n.journalConnectionError,
            style: AppTextStyles.heading(fontSize: 16, color: p.text),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.journalConnectionErrorBody,
            style: AppTextStyles.body(fontSize: 13, color: p.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: onRetry,
            child: Text(
              l10n.journalRetry,
              style: AppTextStyles.body(fontSize: 14, color: p.accent),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyJournal extends StatelessWidget {
  const _EmptyJournal({required this.p, required this.onTap});
  final dynamic p;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('✍️', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 20),
          Text(
            l10n.journalEmptyTitle,
            style: AppTextStyles.display(fontSize: 22, color: p.text),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.journalEmptyBody,
            style: AppTextStyles.body(
              fontSize: 14,
              color: p.textMuted,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Pressable(
            onTap: onTap,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                color: p.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                l10n.journalWriteFirst,
                style: AppTextStyles.body(
                  fontSize: 15,
                  color: p.onAccent,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── New entry button ─────────────────────────────────────────────────────────

class _NewEntryButton extends StatelessWidget {
  const _NewEntryButton({required this.onTap, required this.p});
  final VoidCallback onTap;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: p.accent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          l10n.journalNewEntry,
          style: AppTextStyles.body(
            fontSize: 15,
            color: p.onAccent,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ─── Entry card ───────────────────────────────────────────────────────────────

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.p});
  final JournalEntry entry;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Pressable(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          border: Border.all(color: p.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDate(entry.createdAt, l10n),
              style: AppTextStyles.sectionLabel(color: p.textMuted),
            ),
            const SizedBox(height: 6),
            Text(
              entry.body,
              style: AppTextStyles.heading(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: p.text,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (entry.ilndReply.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                entry.ilndReply,
                style: AppTextStyles.body(
                  fontSize: 13,
                  color: p.textMuted,
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Write bottom sheet ───────────────────────────────────────────────────────

// Date formatting is locale-aware via AppLocalizations month/day arrays —
// kept Turkish-only here intentionally is NOT desired, so resolve via l10n
// at call sites instead. This helper is only used with a BuildContext
// available at each call site below.
String _formatDate(DateTime dt, AppLocalizations l10n) {
  final months = l10n.journalMonths.split(',');
  final days = l10n.journalWeekdaysShort.split(',');
  return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]}';
}

void _showWriteSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.charcoal.withValues(alpha: 0.45),
    isScrollControlled: true,
    builder: (ctx) => const _WriteSheet(),
  );
}

enum _WritePhase { writing, reflecting, response }

class _WriteSheet extends ConsumerStatefulWidget {
  const _WriteSheet();

  @override
  ConsumerState<_WriteSheet> createState() => _WriteSheetState();
}

class _WriteSheetState extends ConsumerState<_WriteSheet> {
  final _controller = TextEditingController();
  _WritePhase _phase = _WritePhase.writing;
  String _ilndReply = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _todayLabel(AppLocalizations l10n) {
    final months = l10n.journalMonths.split(',');
    final days = l10n.journalWeekdaysLong.split(',');
    final now = DateTime.now();
    // weekday: 1=Mon … 7=Sun
    return '${now.day} ${months[now.month - 1]}, ${days[now.weekday - 1]}';
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();
    // Kayıt akışı devam eder — destek dayatılmaz, sunulur.
    if (CrisisGuard.matches(text)) showCrisisResourceSheet(context);
    setState(() => _phase = _WritePhase.reflecting);

    final memory = ref.read(ilndMemoryProvider);
    final service = ref.read(ilndServiceProvider);

    String reply;
    try {
      reply = await service.respond(
        memory: memory,
        userMessage: 'Günlüğüme şunu yazdım:\n$text',
        task:
            'Kullanıcının günlüğüne yargısız, sıcak ve kısa bir karşılık ver. '
            'Önce duygusunu karşıla, sonra düşünmeye davet eden tek nazik bir '
            'soru sor. Liste yapma, 2-3 cümleyi geçme.',
        tier: IlndTier.deep,
        fallback: IlndFallbacks.journal(l10n),
        l10n: l10n,
      );
    } catch (e) {
      reply = IlndService.friendlyError(e, l10n);
    }

    // Firestore'a kaydet
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

    // ILND günlükten kalıcı hafıza biriktirir (fire-and-forget).
    unawaited(ref.read(ilndLearnerProvider).learnFrom(text, l10n));

    if (mounted) {
      setState(() {
        _ilndReply = reply;
        _phase = _WritePhase.response;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: p.base,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: p.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _todayLabel(l10n),
                style: AppTextStyles.sectionLabel(color: p.textMuted),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _phase == _WritePhase.response
                ? _ResponseView(
                    reply: _ilndReply,
                    entry: _controller.text,
                    p: p,
                  )
                : _WritingView(controller: _controller, p: p),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              0,
              AppSpacing.screenPadding,
              24,
            ),
            child: Pressable(
              onTap: _phase == _WritePhase.reflecting
                  ? null
                  : (_phase == _WritePhase.response
                        ? () => Navigator.of(context).pop()
                        : _save),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: _phase == _WritePhase.reflecting
                      ? p.accent.withValues(alpha: 0.5)
                      : p.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: _phase == _WritePhase.reflecting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: p.onAccent,
                        ),
                      )
                    : Text(
                        _phase == _WritePhase.response
                            ? l10n.journalDone
                            : l10n.journalSave,
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
    );
  }
}

// ─── Writing view ─────────────────────────────────────────────────────────────

class _WritingView extends StatelessWidget {
  const _WritingView({required this.controller, required this.p});
  final TextEditingController controller;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: TextField(
        controller: controller,
        autofocus: true,
        maxLines: null,
        expands: true,
        textCapitalization: TextCapitalization.sentences,
        style: AppTextStyles.display(
          fontSize: 20,
          fontWeight: FontWeight.w400,
          color: p.text,
          height: 1.55,
        ),
        decoration: InputDecoration(
          hintText: l10n.journalWritingHint,
          hintStyle: AppTextStyles.display(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            color: p.textMuted.withValues(alpha: 0.7),
            height: 1.55,
          ),
          border: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

// ─── ILND response view ───────────────────────────────────────────────────────

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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
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
