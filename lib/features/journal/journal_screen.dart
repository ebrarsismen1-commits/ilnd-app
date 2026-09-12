import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ilnd_app/core/widgets/ilnd_toast.dart';
import 'package:ilnd_app/core/widgets/confirm_delete.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/ilnd/ilnd_fallbacks.dart';
import 'package:ilnd_app/core/ilnd/ilnd_learner.dart';
import 'package:ilnd_app/core/ilnd/crisis_guard.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/ilnd/ilnd_service.dart';
import 'package:ilnd_app/core/repositories/journal_repository.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/ilnd_surfaces.dart';
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
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Günlük "ekle" sheet'inden push ediliyor, yani sekme değil bir
            // yaprak ekran — kendi çıkışını taşımak zorunda. Yoksa web'de
            // dönüş yolu HİÇ olmuyor (donanım tuşu/kenar kaydırma yok) ve
            // kullanıcı ekranda kilitli kalıyor.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  8,
                  AppSpacing.screenPadding,
                  0,
                ),
                child: IlndPageHeader(
                  p: p,
                  title: l10n.journalTitle,
                  subtitle: l10n.journalSubtitle,
                ),
              ),
            ),
            // Boş günlükte üstte ayrıca "yeni yaz" durmaz: boş durumun
            // kendi daveti ve düğmesi var (Ada tasarımı 05).
            if (entriesAsync.valueOrNull?.isNotEmpty ?? false)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    20,
                    AppSpacing.screenPadding,
                    0,
                  ),
                  child: IlndButton(
                    p: p,
                    label: l10n.journalNewEntry,
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
          Icon(Icons.wifi_off_rounded, size: 32, color: p.textMuted),
          const SizedBox(height: 16),
          Text(
            l10n.journalConnectionError,
            style: AppTextStyles.heading(fontSize: 15, color: p.text),
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
              style: AppTextStyles.body(fontSize: 13, color: p.accent),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

/// Boş günlük (Ada tasarımı 05): davet kartı, günün sorusu, ilk yazı.
/// Boş durum bir özür değil, davet (DESIGN_SYSTEM §6).
class _EmptyJournal extends StatelessWidget {
  const _EmptyJournal({required this.p, required this.onTap});
  final AppPalette p;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        20,
        AppSpacing.screenPadding,
        32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IlndCard(
            p: p,
            color: p.surfaceStrong,
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: p.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.menu_book_outlined,
                    size: 26,
                    color: p.accent,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.journalEmptyTitle,
                  style: AppTextStyles.serifTitle(color: p.text),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.journalEmptyBody,
                  style: AppTextStyles.body(
                    fontSize: 13,
                    color: p.textMuted,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.journalQuestionLabel,
            style: AppTextStyles.caption(color: p.textMuted),
          ),
          const SizedBox(height: 10),
          IlndCard(
            p: p,
            onTap: onTap,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
            child: Text(
              l10n.journalQuestion,
              style: AppTextStyles.serifTitle(color: p.text),
            ),
          ),
          const SizedBox(height: 20),
          IlndButton(p: p, label: l10n.journalWriteFirst, onTap: onTap),
          const SizedBox(height: 14),
          Text(
            l10n.journalNoWrongAnswer,
            style: AppTextStyles.body(fontSize: 12, color: p.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Entry card ───────────────────────────────────────────────────────────────

class _EntryCard extends ConsumerWidget {
  const _EntryCard({required this.entry, required this.p});
  final JournalEntry entry;
  final AppPalette p;

  /// Uzun basma silme kapısı.
  ///
  /// Kart kısa dokunuşa bilerek tepkisiz: eskiden boş `onTap`'li bir
  /// Pressable basma efekti verip hiçbir şey yapmıyordu (yanıltıcı dokunma
  /// hedefi). Silme geri alınamadığı için onay şart.
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await confirmDelete(
      context,
      title: l10n.journalDeleteTitle,
      body: l10n.journalDeleteBody,
    );
    if (!ok || !context.mounted) return;

    final repo = ref.read(journalRepositoryProvider);
    if (repo == null) return;
    try {
      await repo.delete(entry.id);
      if (context.mounted) IlndToast.success(context, l10n.journalDeleted);
    } catch (_) {
      if (context.mounted) IlndToast.error(context, l10n.journalDeleteFailed);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onLongPress: () => _confirmDelete(context, ref),
      child: IlndCard(
        p: p,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDate(entry.createdAt, l10n).toUpperCase(),
              style: AppTextStyles.caption(color: p.textMuted),
            ),
            const SizedBox(height: 8),
            Text(
              entry.body,
              style: AppTextStyles.serifTitle(color: p.text, fontSize: 18),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (entry.ilndReply.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                entry.ilndReply,
                style: AppTextStyles.body(
                  fontSize: 12.5,
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
          fontSize: 19,
          fontWeight: FontWeight.w400,
          color: p.text,
          height: 1.55,
        ),
        decoration: InputDecoration(
          hintText: l10n.journalWritingHint,
          hintStyle: AppTextStyles.display(
            fontSize: 19,
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
              fontSize: 15,
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
