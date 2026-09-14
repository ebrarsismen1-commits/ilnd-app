import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/ilnd/streak_copy.dart';
import 'package:ilnd_app/core/repositories/plans_repository.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/services/reminder_provider.dart';
import 'package:ilnd_app/core/services/streak_tracker.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/utils/possessive.dart';
import 'package:ilnd_app/core/widgets/breath_animation.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/ilnd_surfaces.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/home/home_recommendation.dart';
import 'package:ilnd_app/features/adan/adan_model.dart';
import 'package:ilnd_app/features/adan/island_name_provider.dart';
import 'package:ilnd_app/features/adan/adan_repository.dart';
import 'package:ilnd_app/features/adan/island_scene.dart';
import 'package:ilnd_app/features/journal/journal_screen.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/plans/plan_detail_screen.dart';
import 'package:ilnd_app/features/plans/plan_model.dart';
import 'package:ilnd_app/features/profile/avatar_edit.dart';
import 'package:ilnd_app/features/profile/profile_provider.dart';
import 'package:ilnd_app/features/sleep_ritual/sleep_ritual_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Personal island first, then the daily recommendation and supporting tools.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.hourOverride});
  final int? hourOverride;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  static const _visitKey = 'home_last_visit';
  Timer? _clock;
  late bool _returning;
  bool _foreground = true;
  late DateTime _observedDay;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    final previous = DateTime.tryParse(prefs.getString(_visitKey) ?? '');
    _observedDay = DateTime.now();
    _returning =
        previous != null && _observedDay.difference(previous).inDays >= 7;
    _recordVisit();
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  void _recordVisit() {
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setString(_visitKey, DateTime.now().toIso8601String()),
    );
  }

  void _refresh() {
    if (!mounted || !_foreground) return;
    final now = DateTime.now();
    if (DateUtils.dateOnly(now) != DateUtils.dateOnly(_observedDay)) {
      ref.invalidate(todaysMoodProvider);
      ref.invalidate(sleepRitualDoneTonightProvider);
    }
    _observedDay = now;
    _recordVisit();
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final previous = DateTime.tryParse(
        ref.read(sharedPreferencesProvider).getString(_visitKey) ?? '',
      );
      if (previous != null && DateTime.now().difference(previous).inDays >= 7) {
        _returning = true;
      }
      _foreground = true;
      _refresh();
    } else {
      if (_foreground) _recordVisit();
      _foreground = false;
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final onboardingName = ref.watch(userNameProvider);
    final memory = ref.watch(ilndMemoryProvider);
    final name = onboardingName.isNotEmpty ? onboardingName : memory.name;

    // Bildirim penceresini taze tut: 7 gün ileri kayar, bugün check-in
    // yapıldıysa bugünün bildirimi düşer. Metinler l10n'den geçer (Sert
    // Kural #1); sync oturum içinde aynı durum için no-op, her build ucuz.
    final hasActivityToday = ref.watch(todaysMoodProvider) != null;
    unawaited(
      ref
          .read(reminderProvider.notifier)
          .sync(
            title: l10n.reminderNotificationTitle,
            body: l10n.reminderNotificationBody,
            channelName: l10n.reminderSettingLabel,
            hasActivityToday: hasActivityToday,
          ),
    );

    final hour = widget.hourOverride ?? DateTime.now().hour;
    final mood = ref.watch(todaysMoodProvider);
    if (mood != null) _returning = false;
    final recommendation = recommendForHome(
      hour: hour,
      mood: mood,
      returning: _returning,
      ritualDone: ref.watch(sleepRitualDoneTonightProvider),
    );

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
              child: _Header(name: name, p: p, hour: hour),
            ),
            const SizedBox(height: 18),
            Entrance(
              index: 1,
              child: _IslandCard(name: name, p: p),
            ),
            const SizedBox(height: 24),
            Entrance(
              index: 2,
              child: _NextStep(
                p: p,
                recommendation: recommendation,
                mood: mood,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.homeToolsLabel,
              style: AppTextStyles.body(fontSize: 11, color: p.textMuted),
            ),
            const SizedBox(height: 8),
            Entrance(index: 3, child: _Shortcuts(p: p)),
            const _ActivePlanRow(),
          ],
        ),
      ),
    );
  }
}

// ─── Selamlama ────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  const _Header({required this.name, required this.p, required this.hour});
  final int hour;
  final String name;
  final AppPalette p;

  String _greeting(AppLocalizations l10n) {
    final h = hour;
    if (h < 6) return l10n.homeGreetingNight;
    if (h < 12) return l10n.homeGreetingMorning;
    if (h < 18) return l10n.homeGreetingDay;
    return l10n.homeGreetingEvening;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final streak = ref.watch(profileStatsProvider).valueOrNull?.streakDays ?? 0;
    // Streak satırı selamlamanın devamı, ayrı bir banner değil. Dil gurur
    // odaklı, suçluluk yok: StreakCopy bunu garanti ediyor.
    final streakLine = StreakCopy.line(
      current: streak,
      longest: ref.watch(longestStreakProvider),
      l10n: l10n,
    );
    final greeting = _greeting(l10n);
    // Selamlama cümle başı: tasarımda "Günaydın, Ela". Metin .arb'de küçük
    // harfle duruyor (başka yerlerde cümle ortasında kullanılıyor), ilk
    // harf burada büyütülür.
    final opening = capitalizeTr(greeting);
    final who = name.isNotEmpty
        ? l10n.homeGreetingWithName(opening, name)
        : opening;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ilnd.',
                style: AppTextStyles.display(
                  fontSize: 25,
                  color: p.text,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                who,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.display(
                  fontSize: 27,
                  color: p.text,
                  height: 1.2,
                ),
              ),
              if (streakLine != null) ...[
                const SizedBox(height: 6),
                Text(
                  streakLine,
                  style: AppTextStyles.body(fontSize: 13, color: p.textMuted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          label: l10n.a11yOpenProfile,
          child: Pressable(
            onTap: () => context.go(routeProfile),
            // Görsel çap 38 ama dokunma hedefi 44.
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: UserAvatar(
                  size: 38,
                  initial: initial,
                  p: p,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Ada kartı ────────────────────────────────────────────────────────────────

/// Personal island below the greeting, above the daily recommendation.
class _IslandCard extends ConsumerWidget {
  const _IslandCard({required this.name, required this.p});
  final String name;
  final AppPalette p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final island = ref.watch(islandStateProvider).valueOrNull;
    final l10n = AppLocalizations.of(context)!;
    final customName = ref.watch(islandNameProvider).valueOrNull;
    final title =
        customName ??
        (name.isEmpty
            ? l10n.adanTitle
            : l10n.homeIslandOwned(possessiveName(l10n, name)));

    return LayoutBuilder(
      builder: (context, constraints) {
        // Kompakt önizleme. Dar telefonda kısalır, geniş ekranda
        // (web, tablet) tavanda durur: kart hiçbir zaman ekranı yutmaz.
        final height = (constraints.maxWidth / 1.9).clamp(160.0, 220.0);
        return Semantics(
          button: true,
          label: title,
          child: Pressable(
            onTap: () => context.push(routeAdan),
            scaleDown: 0.98,
            child: IslandFrame(
              p: p,
              height: height,
              artwork: IslandScene(
                state: island ?? const IslandState(),
                p: p,
                contentPadding: const EdgeInsets.only(top: 34, bottom: 38),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 14,
                    child: ExcludeSemantics(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.rowTitle(color: p.text),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 14,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
                        decoration: BoxDecoration(
                          color: p.surface.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                l10n.homeIslandVisit,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.body(
                                  fontSize: 12.5,
                                  color: p.textMuted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: p.accent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Ruh hali ─────────────────────────────────────────────────────────────────

class _MoodCheckIn extends ConsumerStatefulWidget {
  const _MoodCheckIn({super.key, required this.p});
  final AppPalette p;

  @override
  ConsumerState<_MoodCheckIn> createState() => _MoodCheckInState();
}

class _MoodCheckInState extends ConsumerState<_MoodCheckIn> {
  // Tasarımdaki çizgi yüzler. Emoji değil ikon: no_emoji_test.
  static const _moods = [
    (Icons.sentiment_satisfied_outlined, 'calm'),
    (Icons.sentiment_very_satisfied_outlined, 'good'),
    (Icons.sentiment_neutral_outlined, 'okay'),
    (Icons.sentiment_dissatisfied_outlined, 'tired'),
    (Icons.sentiment_very_dissatisfied_outlined, 'hard'),
  ];

  int? _selected;

  String _moodLabel(AppLocalizations l10n, String key) => switch (key) {
    'calm' => l10n.homeMoodCalm,
    'good' => l10n.homeMoodGood,
    'okay' => l10n.homeMoodOkay,
    'tired' => l10n.homeMoodTired,
    'hard' => l10n.homeMoodHard,
    _ => key,
  };

  // Selection updates the recommendation in place; navigation requires the CTA.
  // Bir kez cevaplanınca günün geri kalanında tekrar sorulmaz.
  Future<void> _select(int index, AppLocalizations l10n) async {
    if (_selected != null) return;
    setState(() => _selected = index);
    final moodKey = _moods[index].$2;
    await ref.read(todaysMoodProvider.notifier).record(moodKey);
    unawaited(
      ref
          .read(ilndMemoryProvider.notifier)
          // "Bugünkü" YAZILMAZ: not kalıcı, yarın da "bugünkü" derdi.
          // Zamanı notun kendi damgası taşıyor (MemoryNote.at).
          .addNote('Ruh hali: ${_moodLabel(l10n, moodKey)}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = widget.p;
    final todaysMood = ref.watch(todaysMoodProvider);

    if (todaysMood != null) {
      final mood = _moods.firstWhere(
        (m) => m.$2 == todaysMood,
        orElse: () => _moods.first,
      );
      // Cevaplandıktan sonra tek sessiz satır kalır.
      return Row(
        children: [
          Icon(mood.$1, size: 20, color: p.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.homeMoodAnsweredToday(_moodLabel(l10n, todaysMood)),
              style: AppTextStyles.body(fontSize: 13, color: p.textMuted),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.homeMoodQuestion,
          style: AppTextStyles.serifTitle(color: p.text),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            // Beşi her genişlikte tek satırda: daire çapı alana göre küçülür
            // ama 44'ün (dokunma hedefi) altına inmez.
            final size = ((constraints.maxWidth - 4 * 8) / 5).clamp(44.0, 52.0);
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final (index, m) in _moods.indexed)
                  Semantics(
                    button: true,
                    selected: _selected == index,
                    label: _moodLabel(l10n, m.$2),
                    excludeSemantics: true,
                    child: Pressable(
                      onTap: () => _select(index, l10n),
                      child: SizedBox(
                        width: size,
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              width: size,
                              height: size,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _selected == index
                                    ? p.accentSoft
                                    : p.surface,
                                border: Border.all(
                                  color: _selected == index
                                      ? p.accent
                                      : p.border,
                                  width: _selected == index ? 1.5 : 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: AnimatedScale(
                                scale: _selected == index ? 1.15 : 1.0,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                                child: Icon(
                                  m.$1,
                                  size: size * 0.46,
                                  color: _selected == index ? p.accent : p.text,
                                ),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              _moodLabel(l10n, m.$2),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              softWrap: true,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body(
                                fontSize: 12,
                                color: _selected == index
                                    ? p.accent
                                    : p.textMuted,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ─── Günün küçük pratiği ─────────────────────────────────────────────────────

class _NextStep extends StatelessWidget {
  const _NextStep({
    required this.p,
    required this.recommendation,
    required this.mood,
  });
  final AppPalette p;
  final HomeRecommendation recommendation;
  final String? mood;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final (title, body, cta) = switch (recommendation) {
      HomeRecommendation.restart => (
        l.homeNextRestartTitle,
        l.homeNextRestartBody,
        l.homeNextRestartCta,
      ),
      HomeRecommendation.morning => (
        l.homeNextMorningTitle,
        l.homeNextMorningBody,
        l.homeNextMorningCta,
      ),
      HomeRecommendation.checkIn => (
        l.homeNextCheckInTitle,
        l.homeNextCheckInBody,
        l.homeNextCheckInCta,
      ),
      HomeRecommendation.rest => (
        l.homeNextRestTitle,
        l.homeNextRestBody,
        l.homeNextRestCta,
      ),
      HomeRecommendation.focus => (
        l.homeNextFocusTitle,
        l.homeNextFocusBody,
        l.homeNextFocusCta,
      ),
      HomeRecommendation.journal => (
        l.homeNextJournalTitle,
        l.homeNextJournalBody,
        l.homeNextJournalCta,
      ),
      HomeRecommendation.night => (
        l.sleepRitualHomeCardTitle,
        l.homeNextNightBody,
        l.homeNextNightCta,
      ),
    };
    final feedback = switch (mood) {
      'calm' => l.homeFeedbackCalm,
      'good' => l.homeFeedbackGood,
      'okay' => l.homeFeedbackOkay,
      'tired' => l.homeFeedbackTired,
      'hard' => l.homeFeedbackHard,
      _ => null,
    };
    return IlndCard(
      p: p,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.homeNextLabel,
            style: AppTextStyles.body(fontSize: 11, color: p.textMuted),
          ),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.display(
                    fontSize: 27,
                    color: p.text,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                if (feedback != null) ...[
                  Text(
                    feedback,
                    style: AppTextStyles.body(fontSize: 14, color: p.text),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  body,
                  style: AppTextStyles.body(fontSize: 14, color: p.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _MoodCheckIn(key: ValueKey(DateUtils.dateOnly(DateTime.now())), p: p),
          const SizedBox(height: 20),
          IlndButton(
            key: const ValueKey('home-primary-action'),
            p: p,
            label: cta,
            onTap: () {
              switch (recommendation) {
                case HomeRecommendation.night:
                  context.push(routeSleepRitual);
                case HomeRecommendation.focus:
                  context.push(routeFocus);
                case HomeRecommendation.journal:
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const JournalScreen(),
                    ),
                  );
                case HomeRecommendation.rest:
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => BreathScreen(p: p)),
                  );
                case HomeRecommendation.restart:
                case HomeRecommendation.morning:
                case HomeRecommendation.checkIn:
                  context.push(routeChat);
              }
            },
          ),
        ],
      ),
    );
  }
}

// ─── Üç kapı ──────────────────────────────────────────────────────────────────

class _Shortcuts extends StatelessWidget {
  const _Shortcuts({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _ShortcutTile(
            p: p,
            icon: Icons.menu_book_outlined,
            label: l10n.journalTitle,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const JournalScreen()),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ShortcutTile(
            p: p,
            icon: Icons.schedule_rounded,
            label: l10n.homeShortcutFocus,
            onTap: () => context.push(routeFocus),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ShortcutTile(
            p: p,
            icon: Icons.water_drop_outlined,
            label: l10n.takipTitle,
            onTap: () => context.push(routeTakip),
          ),
        ),
      ],
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.p,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final AppPalette p;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: p.textMuted),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(fontSize: 13, color: p.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Aktif plan satırı (ADR-0005) ─────────────────────────────────────────────

/// Devam eden planın bir sonraki günü. Plan yoksa, plan bittiyse ya da içerik
/// henüz yüklenmediyse hiçbir şey çizilmez: başlığı olmayan bir özelliğin
/// sözünü vermek olurdu.
class _ActivePlanRow extends ConsumerWidget {
  const _ActivePlanRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(activePlanProvider);
    if (plan == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final localized = plan.forLocale(l10n.localeName);
    final progressState = ref.watch(planProgressProvider(plan.id));
    if (progressState.isLoading) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          l10n.stateLoading,
          style: AppTextStyles.body(fontSize: 12, color: p.textMuted),
        ),
      );
    }
    if (progressState.hasError) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.stateError,
                style: AppTextStyles.body(fontSize: 12, color: p.textMuted),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(planProgressProvider(plan.id)),
              child: Text(l10n.stateRetry),
            ),
          ],
        ),
      );
    }
    final progress = progressState.valueOrNull ?? const PlanProgress();
    final next = progress.nextDay(localized);
    if (next == null) return const SizedBox.shrink(); // plan bitti

    final dayNumber = localized.days.indexWhere((d) => d.id == next.id) + 1;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: IlndCard(
        p: p,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => PlanDetailScreen(plan: plan)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.homeActivePlanLabel,
                    style: AppTextStyles.caption(color: p.accent),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${l10n.planDayLabel(dayNumber)}: ${next.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.rowTitle(color: p.text),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l10n.planProgress(
                      progress.doneCountIn(localized),
                      localized.lengthDays,
                    ),
                    style: AppTextStyles.body(fontSize: 12, color: p.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 22, color: p.textMuted),
          ],
        ),
      ),
    );
  }
}
