import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ilnd_app/core/repositories/events_repository.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
import 'package:ilnd_app/core/widgets/breath_ring.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/ilnd_toast.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Topluluk v2 (ADR-0002): gerçek etkinlik listesi + RSVP.
/// Etkinlik yoksa v1 davet içeriği görünür — sekme hiçbir durumda boş değil.
class TopulukScreen extends ConsumerWidget {
  const TopulukScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final events = ref.watch(upcomingEventsProvider).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: p.base,
      body: AnimatedBackground(
        palette: p,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 28),
                Entrance(
                  index: 0,
                  child: Text(
                    l10n.topulukTitle,
                    style: AppTextStyles.display(fontSize: 30, color: p.text),
                  ),
                ),
                const SizedBox(height: 4),
                Entrance(
                  index: 1,
                  child: Text(
                    l10n.topulukTagline,
                    style: AppTextStyles.body(fontSize: 13, color: p.textMuted),
                  ),
                ),
                const SizedBox(height: 24),
                if (events.isEmpty)
                  _EmptyInvite(l10n: l10n, p: p)
                else ...[
                  Entrance(
                    index: 2,
                    child: Text(
                      l10n.topulukUpcomingLabel,
                      style: AppTextStyles.sectionLabel(color: p.textMuted),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final (i, e) in events.indexed) ...[
                    Entrance(
                      index: 3 + i,
                      child: _EventCard(event: e, p: p),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
                  Entrance(
                    index: 3 + events.length,
                    child: _InviteRow(l10n: l10n, p: p),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Etkinlik kartı ───────────────────────────────────────────────────────────

class _EventCard extends ConsumerWidget {
  const _EventCard({required this.event, required this.p});
  final CommunityEvent event;
  final AppPalette p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final going = ref.watch(myRsvpProvider(event.id)).valueOrNull ?? false;
    final count = ref.watch(rsvpCountProvider(event.id)).valueOrNull ?? 0;
    final locale = l10n.localeName;
    final day = DateFormat('d', locale).format(event.startsAt);
    final month = DateFormat(
      'MMM',
      locale,
    ).format(event.startsAt).toUpperCase();

    Future<void> toggle() async {
      final repo = ref.read(eventsRepositoryProvider);
      if (repo == null) return;
      try {
        going ? await repo.cancelRsvp(event.id) : await repo.rsvp(event.id);
      } catch (_) {
        if (context.mounted) IlndToast.error(context, l10n.topulukRsvpFailed);
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: p.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  day,
                  style: AppTextStyles.mono(
                    fontSize: 16,
                    color: p.accent,
                  ).copyWith(fontWeight: FontWeight.w700, height: 1.1),
                ),
                Text(
                  month,
                  style: AppTextStyles.label(fontSize: 8.5, color: p.accent),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: AppTextStyles.heading(fontSize: 15.5, color: p.text),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 13, color: p.textMuted),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        '${event.venue} · ${event.city}',
                        style: AppTextStyles.body(
                          fontSize: 11,
                          color: p.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (count > 0)
                      Expanded(
                        child: Text(
                          l10n.topulukGoingCount(count),
                          style: AppTextStyles.body(
                            fontSize: 10.5,
                            color: p.textMuted,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    Pressable(
                      onTap: toggle,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: going ? p.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: p.accent, width: 1),
                        ),
                        child: Text(
                          going ? l10n.topulukRsvpGoing : l10n.topulukRsvpJoin,
                          style: AppTextStyles.body(
                            fontSize: 11.5,
                            color: going ? p.onAccent : p.accent,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Boş durum: v1 davet içeriği ─────────────────────────────────────────────

class _EmptyInvite extends StatelessWidget {
  const _EmptyInvite({required this.l10n, required this.p});
  final AppLocalizations l10n;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Entrance(index: 2, child: Center(child: BreathRing(size: 96))),
        const SizedBox(height: 32),
        Entrance(
          index: 3,
          child: Text(
            l10n.topulukComingTitle,
            style: AppTextStyles.heading(fontSize: 22, color: p.text),
          ),
        ),
        const SizedBox(height: 10),
        Entrance(
          index: 4,
          child: Text(
            l10n.topulukComingBody,
            style: AppTextStyles.body(
              fontSize: 14,
              color: p.textMuted,
            ).copyWith(height: 1.6),
          ),
        ),
        const SizedBox(height: 28),
        Entrance(
          index: 5,
          child: _InviteRow(l10n: l10n, p: p),
        ),
      ],
    );
  }
}

class _InviteRow extends StatelessWidget {
  const _InviteRow({required this.l10n, required this.p});
  final AppLocalizations l10n;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => context.push(routeReferral),
      child: Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          color: p.accent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          l10n.topulukInviteCta,
          style: AppTextStyles.body(
            fontSize: 15,
            color: p.onAccent,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
