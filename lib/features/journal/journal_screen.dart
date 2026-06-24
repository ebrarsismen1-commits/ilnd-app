import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/ilnd/ilnd_fallbacks.dart';
import 'package:ilnd_app/core/ilnd/ilnd_learner.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/ilnd/ilnd_service.dart';
import 'package:ilnd_app/core/repositories/journal_repository.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';

// ─── Screen ──────────────────────────────────────────────────────────────────

class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    AppSpacing.screenPadding, 28, AppSpacing.screenPadding, 0),
                  child: Text('günlük.',
                      style: AppTextStyles.display(fontSize: 32, color: p.text)),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding, 20, AppSpacing.screenPadding, 0),
                  child: _NewEntryButton(p: p, onTap: () => _showWriteSheet(context, ref)),
                ),
              ),
              entriesAsync.when(
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, st) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text('Yüklenemedi', style: AppTextStyles.body(fontSize: 14, color: p.textMuted)),
                  ),
                ),
                data: (entries) => entries.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyJournal(p: p, onTap: () => _showWriteSheet(context, ref)),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenPadding, 20, AppSpacing.screenPadding, 32),
                        sliver: SliverList.separated(
                          itemCount: entries.length,
                          separatorBuilder: (ctx2, i2) => const SizedBox(height: 12),
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

// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyJournal extends StatelessWidget {
  const _EmptyJournal({required this.p, required this.onTap});
  final dynamic p;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('✍️', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 20),
          Text(
            'henüz bir yazı yok.',
            style: AppTextStyles.display(fontSize: 22, color: p.text),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Bugün ne hissettiğini yaz.\nİlk kelimeyi sen koy, geri kalanı gelir.',
            style: AppTextStyles.body(fontSize: 14, color: p.textMuted, height: 1.5),
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
                'ilk yazıyı yaz',
                style: AppTextStyles.body(fontSize: 15, color: p.onAccent)
                    .copyWith(fontWeight: FontWeight.w600),
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
          'yeni yazı yaz +',
          style: AppTextStyles.body(fontSize: 15, color: p.onAccent)
              .copyWith(fontWeight: FontWeight.w600),
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
            Text(_formatDate(entry.createdAt), style: AppTextStyles.sectionLabel(color: p.textMuted)),
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
                style: AppTextStyles.body(fontSize: 13, color: p.textMuted, height: 1.5),
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

String _formatDate(DateTime dt) {
  const months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];
  const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
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

  String get _todayLabel {
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    const days = [
      'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
    ];
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

    FocusScope.of(context).unfocus();
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
        fallback: IlndFallbacks.journal(),
      );
    } catch (e) {
      reply = IlndService.friendlyError(e);
    }

    // Firestore'a kaydet
    final repo = ref.read(journalRepositoryProvider);
    if (repo != null) {
      unawaited(repo.add(JournalEntry(
        id: '',
        body: text,
        ilndReply: reply,
        createdAt: DateTime.now(),
      )));
    }

    await ref
        .read(ilndMemoryProvider.notifier)
        .addNote('Günlük: ${text.length > 80 ? '${text.substring(0, 80)}…' : text}');

    // ILND günlükten kalıcı hafıza biriktirir (fire-and-forget).
    unawaited(ref.read(ilndLearnerProvider).learnFrom(text));

    if (mounted) {
      setState(() {
        _ilndReply = reply;
        _phase = _WritePhase.response;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(_todayLabel, style: AppTextStyles.sectionLabel(color: p.textMuted)),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _phase == _WritePhase.response
                ? _ResponseView(reply: _ilndReply, entry: _controller.text, p: p)
                : _WritingView(controller: _controller, p: p),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding, 0, AppSpacing.screenPadding, 24),
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
                        child: CircularProgressIndicator(strokeWidth: 2, color: p.onAccent),
                      )
                    : Text(
                        _phase == _WritePhase.response ? 'tamam' : 'kaydet',
                        style: AppTextStyles.body(fontSize: 15, color: p.onAccent)
                            .copyWith(fontWeight: FontWeight.w600),
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
          hintText: 'bugün ne hissediyorsun?',
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
  const _ResponseView({required this.reply, required this.entry, required this.p});
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
                  decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text('i',
                      style: AppTextStyles.display(fontSize: 15, color: p.onAccent)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    reply,
                    style: AppTextStyles.body(fontSize: 15, height: 1.5, color: p.text),
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
