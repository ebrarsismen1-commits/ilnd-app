import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/billing/entitlement.dart';
import 'package:ilnd_app/core/repositories/movement_repository.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/cover_image.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/movement/movement_player_screen.dart';
import 'package:ilnd_app/features/movement/movement_program.dart';
import 'package:ilnd_app/features/premium/paywall_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Bir hareket programının detayı: kapak, tanıtım, seans listesi ve
/// kullanıcının ilerlemesi (ADR-0004).
class MovementProgramScreen extends ConsumerWidget {
  const MovementProgramScreen({super.key, required this.program});

  final MovementProgram program;

  static String levelLabel(MovementLevel level, AppLocalizations l10n) =>
      switch (level) {
        MovementLevel.easy => l10n.movementLevelEasy,
        MovementLevel.medium => l10n.movementLevelMedium,
        MovementLevel.strong => l10n.movementLevelStrong,
      };

  Future<void> _openSession(
    BuildContext context,
    WidgetRef ref,
    MovementSession session,
    AppLocalizations l10n,
  ) async {
    // Kilitli programda seans açılmaz — paywall açılır. Kontrol her girişte
    // yapılır (kart üzerinden de, "devam et" üzerinden de aynı kapı).
    if (program.premium && !ref.read(hasPremiumAccessProvider)) {
      await PaywallScreen.show(context, reason: l10n.movementPaywallReason);
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MovementPlayerScreen(program: program, session: session),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final localized = program.forLocale(l10n.localeName);
    final sessions = localized.playableSessions;
    final progress =
        ref.watch(movementProgressProvider(program.id)).valueOrNull ??
        const MovementProgress();

    final done = progress.doneCountIn(localized);
    final complete = progress.isComplete(localized);
    final next = progress.nextSession(localized);

    return Scaffold(
      backgroundColor: p.base,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: CoverImage(imageUrl: localized.coverUrl, palette: 0),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 120,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Semantics(
                      button: true,
                      label: l10n.a11yBack,
                      child: Pressable(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              20,
              AppSpacing.screenPadding,
              32,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  localized.title,
                  style: AppTextStyles.display(fontSize: 28, color: p.text),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(text: levelLabel(localized.level, l10n), p: p),
                    _Chip(
                      text: l10n.movementSessionCount(sessions.length),
                      p: p,
                    ),
                    if (localized.totalMinutes > 0)
                      _Chip(
                        text: l10n.movementMinutes(localized.totalMinutes),
                        p: p,
                      ),
                    if (localized.premium)
                      _Chip(
                        text: l10n.movementPremiumBadge,
                        p: p,
                        accent: true,
                      ),
                  ],
                ),
                if (localized.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    localized.description,
                    style: AppTextStyles.body(
                      fontSize: 15,
                      color: p.textMuted,
                    ).copyWith(height: 1.6),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  complete
                      ? l10n.movementAllDone
                      : l10n.movementProgress(done, sessions.length),
                  style: AppTextStyles.label(fontSize: 11.5, color: p.accent),
                ),
                const SizedBox(height: 12),
                if (next != null)
                  _PrimaryButton(
                    label: complete
                        ? l10n.movementReplay
                        : (done == 0
                              ? l10n.movementStart
                              : l10n.movementContinue),
                    p: p,
                    onTap: () => _openSession(context, ref, next, l10n),
                  ),
                const SizedBox(height: 24),

                for (var i = 0; i < sessions.length; i++) ...[
                  _SessionRow(
                    index: i + 1,
                    session: sessions[i],
                    done: progress.isDone(sessions[i].id),
                    locked:
                        localized.premium &&
                        !ref.watch(hasPremiumAccessProvider),
                    p: p,
                    l10n: l10n,
                    onTap: () => _openSession(context, ref, sessions[i], l10n),
                  ),
                  if (i != sessions.length - 1) const SizedBox(height: 10),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.p, this.accent = false});

  final String text;
  final AppPalette p;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent ? p.accent.withValues(alpha: 0.14) : p.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: accent ? p.accent : p.border, width: 0.5),
      ),
      child: Text(
        text,
        style: AppTextStyles.label(
          fontSize: 10,
          color: accent ? p.accent : p.textMuted,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.p,
    required this.onTap,
  });

  final String label;
  final AppPalette p;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.accent,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
        child: Text(
          label,
          style: AppTextStyles.label(fontSize: 11.5, color: p.onAccent),
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.index,
    required this.session,
    required this.done,
    required this.locked,
    required this.p,
    required this.l10n,
    required this.onTap,
  });

  final int index;
  final MovementSession session;
  final bool done;
  final bool locked;
  final AppPalette p;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: done ? p.accent : p.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: done
                  ? Icon(Icons.check_rounded, size: 18, color: p.onAccent)
                  : Text(
                      '$index',
                      style: AppTextStyles.label(
                        fontSize: 11.5,
                        color: p.accent,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(fontSize: 13, color: p.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    done
                        ? l10n.movementSessionDone
                        : (session.minutes > 0
                              ? l10n.movementMinutes(session.minutes)
                              : ''),
                    style: AppTextStyles.body(
                      fontSize: 11.5,
                      color: p.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              locked ? Icons.lock_outline_rounded : Icons.play_arrow_rounded,
              size: 20,
              color: p.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
