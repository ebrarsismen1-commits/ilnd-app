import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ilnd_app/core/repositories/events_repository.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/breath_ring.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/ilnd_surfaces.dart';
import 'package:ilnd_app/core/widgets/ilnd_toast.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Topluluk (Ada tasarımı 09, ADR-0002): gerçek etkinlik listesi + RSVP.
/// Etkinlik yoksa davet içeriği görünür — sekme hiçbir durumda boş değil.
class TopulukScreen extends ConsumerWidget {
  const TopulukScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final events = ref.watch(upcomingEventsProvider).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: p.base,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            12,
            AppSpacing.screenPadding,
            32,
          ),
          children: [
            Entrance(
              index: 0,
              child: IlndPageHeader(
                p: p,
                title: l10n.topulukTitle,
                subtitle: l10n.topulukTagline,
                showBack: false,
                titleSize: 28,
              ),
            ),
            const SizedBox(height: 22),
            if (events.isEmpty)
              _EmptyInvite(l10n: l10n, p: p)
            else ...[
              Entrance(
                index: 1,
                child: Text(
                  l10n.topulukUpcomingLabel,
                  style: AppTextStyles.caption(color: p.textMuted),
                ),
              ),
              const SizedBox(height: 10),
              for (final (i, e) in events.indexed) ...[
                Entrance(
                  index: 2 + i,
                  child: _EventCard(event: e, p: p),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              Entrance(
                index: 2 + events.length,
                child: IlndButton(
                  p: p,
                  label: l10n.topulukInviteCta,
                  onTap: () => context.push(routeReferral),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Etkinlik kartı ────────────────────────────────────────────────────────────

class _EventCard extends ConsumerWidget {
  const _EventCard({required this.event, required this.p});
  final CommunityEvent event;
  final AppPalette p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final going = ref.watch(myRsvpProvider(event.id)).valueOrNull ?? false;
    final count = ref.watch(rsvpCountProvider(event.id)).valueOrNull ?? 0;

    // Kontenjan etkinlik başına gelir ve olmayabilir (capacity nullable).
    // Katılanlar için kapı kapanmaz: dolu bir etkinlikten çıkabilmeliler.
    //
    // BU KONTROL İSTEMCİDE: Firestore kuralları doküman sayamaz, yani
    // kapasite kuralda uygulanamıyor. Eşzamanlı iki kayıt sınırı bir iki
    // kişi aşabilir; ücretsiz ve küçük buluşmalarda bu kabul edildi
    // (bkz. docs/decisions.md, 2026-08-31). Kontenjanın gerçekten
    // bağlayıcı olması gerekirse RSVP bir Cloud Function'a taşınmalı.
    final capacity = event.capacity;
    final isFull = capacity != null && count >= capacity;
    final locked = isFull && !going;
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
        // Sayı tek seferlik bir Future; yenilenmezse kullanıcı katıldıktan
        // sonra eski sayıyı görür ve kontenjan dolduğu halde dolmamış
        // görünebilir.
        ref.invalidate(rsvpCountProvider(event.id));
      } catch (_) {
        if (context.mounted) IlndToast.error(context, l10n.topulukRsvpFailed);
      }
    }

    return IlndCard(
      p: p,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tarih karosu: Adaçayı zemin, Orman rakam.
          Container(
            width: 52,
            height: 56,
            decoration: BoxDecoration(
              color: p.surfaceStrong,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  day,
                  style: AppTextStyles.mono(
                    fontSize: 20,
                    color: p.accent,
                  ).copyWith(height: 1.1),
                ),
                const SizedBox(height: 2),
                Text(
                  month,
                  style: AppTextStyles.label(fontSize: 9.5, color: p.accent),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: AppTextStyles.serifTitle(color: p.text, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: p.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${event.venue} · ${event.city}',
                        style: AppTextStyles.body(
                          fontSize: 12,
                          color: p.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (count > 0)
                      Expanded(
                        child: Text(
                          capacity == null
                              ? l10n.topulukGoingCount(count)
                              : l10n.topulukGoingCountOfCapacity(
                                  count,
                                  capacity,
                                ),
                          style: AppTextStyles.body(
                            fontSize: 11.5,
                            color: p.textMuted,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    Pressable(
                      onTap: locked ? null : toggle,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        constraints: const BoxConstraints(minHeight: 36),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: going ? p.accent : p.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: locked ? p.border : p.accent,
                          ),
                        ),
                        child: Text(
                          locked
                              ? l10n.topulukRsvpFull
                              : (going
                                    ? l10n.topulukRsvpGoing
                                    : l10n.topulukRsvpJoin),
                          softWrap: false,
                          overflow: TextOverflow.fade,
                          style: AppTextStyles.body(
                            fontSize: 12,
                            color: locked
                                ? p.textMuted
                                : (going ? p.onAccent : p.accent),
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

// ─── Boş durum: davet ─────────────────────────────────────────────────────────

class _EmptyInvite extends StatelessWidget {
  const _EmptyInvite({required this.l10n, required this.p});
  final AppLocalizations l10n;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // İllüstrasyon gelene kadar adanın ortasında nefes halkası durur.
        Entrance(
          index: 1,
          child: IslandFrame(
            p: p,
            height: 170,
            child: const Center(child: BreathRing(size: 64)),
          ),
        ),
        const SizedBox(height: 24),
        Entrance(
          index: 2,
          child: Text(
            l10n.topulukComingTitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.display(fontSize: 25, color: p.text),
          ),
        ),
        const SizedBox(height: 8),
        Entrance(
          index: 3,
          child: Text(
            l10n.topulukComingBody,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              fontSize: 13,
              color: p.textMuted,
              height: 1.55,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Entrance(
          index: 4,
          child: IlndListRow(
            p: p,
            icon: Icons.location_on_outlined,
            title: l10n.topulukCityTitle,
            subtitle: l10n.topulukCitySubtitle,
          ),
        ),
        const SizedBox(height: 10),
        Entrance(
          index: 5,
          child: IlndCard(
            p: p,
            color: p.surfaceStrong,
            child: Row(
              children: [
                Icon(Icons.people_outline_rounded, size: 26, color: p.accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.topulukTogetherTitle,
                        style: AppTextStyles.rowTitle(color: p.text),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l10n.topulukTogetherBody,
                        style: AppTextStyles.body(
                          fontSize: 12,
                          color: p.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Entrance(
          index: 6,
          child: IlndButton(
            p: p,
            label: l10n.topulukInviteCta,
            onTap: () => context.push(routeReferral),
          ),
        ),
      ],
    );
  }
}
