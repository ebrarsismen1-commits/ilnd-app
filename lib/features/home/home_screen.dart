import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/ilnd/streak_copy.dart';
import 'package:ilnd_app/core/repositories/plans_repository.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/services/reminder_provider.dart';
import 'package:ilnd_app/core/services/streak_tracker.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/cover_image.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/adan/adan_model.dart';
import 'package:ilnd_app/features/adan/adan_repository.dart';
import 'package:ilnd_app/features/adan/adan_screen.dart';
import 'package:ilnd_app/features/explore/article_detail_screen.dart';
import 'package:ilnd_app/core/repositories/explore_repository.dart';
import 'package:ilnd_app/features/explore/article_model.dart';
import 'package:ilnd_app/features/home/daily_read.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/plans/plan_detail_screen.dart';
import 'package:ilnd_app/features/plans/plan_model.dart';
import 'package:ilnd_app/features/profile/avatar_edit.dart';
import 'package:ilnd_app/features/profile/profile_provider.dart';
import 'package:ilnd_app/features/sleep_ritual/sleep_ritual_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.hourOverride});

  /// Saat testte enjekte edilir; null'sa cihaz saati (gece ritüeli daveti).
  final int? hourOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    // Bu saatin okuması: Firestore kütüphanesinden, onboarding hedeflerine
    // öncelik vererek, saat başı değişerek (daily_read.dart). Firestore
    // henüz gelmediyse kod-içi yedeğe düşer, ekran boş kalmaz.
    final fetched = ref.watch(articlesProvider).valueOrNull;
    final library = (fetched == null || fetched.isEmpty) ? kArticles : fetched;
    final read =
        (pickHourlyRead(
                  library: library,
                  goals: ref.watch(onboardingGoalsProvider),
                  now: DateTime.now(),
                ) ??
                kArticles.first)
            .forLocale(l10n.localeName);

    return Scaffold(
      backgroundColor: p.base,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _HeroHeader(name: name, p: p),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                22,
                AppSpacing.screenPadding,
                40,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  // Sıra: hero → mood → adan → plan → sessiz satırlar →
                  // okuma. "Günün üçlüsü" 2026-08-31'de owner kararıyla
                  // kaldırıldı; sessiz satırlar okumanın üstüne alındı. Mood hero'nun hemen altında
                  // yaşar; bindirme (Transform.translate) denenip
                  // bırakılmıştı — layout'u etkilemediği için fontlar geç
                  // yüklenince selamlamanın üstüne biniyordu.
                  Entrance(index: 4, child: _MoodCheckIn(p: p)),
                  const SizedBox(height: 26),
                  _Hairline(p: p),
                  const SizedBox(height: 22),
                  // ADAN bloğu (handoff §1): ilerlemenin yer hâli.
                  Entrance(index: 5, child: _AdanBlock(p: p)),
                  const SizedBox(height: 22),
                  // Aktif plan Bugün'de yaşar: kullanıcı Keşfet'e girmeyi
                  // unutur, ana ekranı unutmaz. Plan yoksa satır hiç
                  // çizilmez (ADR-0005).
                  const _ActivePlanRow(),
                  const SizedBox(height: 18),
                  // Sessiz satırlar okuma kartının ÜSTÜNDE: eyleme çağıran
                  // satırlar (gece ritüeli, takip, haftalık kart) uzun bir
                  // kartın arkasında kalmamalı. Kart değil, hairline ile
                  // ayrılmış satırlar (handoff §1).
                  Entrance(
                    index: 9,
                    child: _QuietRows(
                      p: p,
                      hour: hourOverride ?? DateTime.now().hour,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Entrance(
                    index: 10,
                    child: _SectionLabel(l10n.homeTodaysReadTitle, p: p),
                  ),
                  const SizedBox(height: 12),
                  Entrance(
                    index: 11,
                    child: _DailyReadCard(article: read, p: p),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Top bar ─────────────────────────────────────────────────────────────────

const _uHero = 'https://images.unsplash.com/photo-';

/// Saate göre seçilen, desature edilen (CoverImage) ambiyans fotoğrafı.
/// Ağ yoksa EditorialGradient'e düşer — hero asla kırık görünmez.
String _heroImageUrl(int hour) {
  if (hour >= 6 && hour < 12) {
    // Sisli gün doğumu — sabah.
    return '${_uHero}1517071893752-c61373ceb5f4?auto=format&fit=crop&w=1200&q=70';
  }
  if (hour >= 12 && hour < 18) {
    // Işık alan orman — gündüz.
    return '${_uHero}1425913397330-cf8af2ff40a1?auto=format&fit=crop&w=1200&q=70';
  }
  // Yıldızlı gece — akşam.
  return '${_uHero}1628498188904-036f5e25e93e?auto=format&fit=crop&w=1200&q=70';
}

/// Bugün v2 hero'su: fotoğraf zemin, selamlama fotoğrafın üzerinde yaşar
/// (docs/DESIGN_SYSTEM.md §7 — renk fotoğraftan gelir).
class _HeroHeader extends ConsumerWidget {
  const _HeroHeader({required this.name, required this.p});
  final String name;
  final AppPalette p;

  String _greeting(AppLocalizations l10n) {
    final h = DateTime.now().hour;
    if (h < 6) return l10n.homeGreetingNight;
    if (h < 12) return l10n.homeGreetingMorning;
    if (h < 18) return l10n.homeGreetingDay;
    return l10n.homeGreetingEvening;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final streak = ref.watch(profileStatsProvider).valueOrNull?.streakDays ?? 0;
    final streakLine = StreakCopy.line(
      current: streak,
      longest: ref.watch(longestStreakProvider),
      l10n: l10n,
    );
    final greeting = _greeting(l10n);
    final who = name.isNotEmpty
        ? l10n.homeGreetingWithName(greeting, name)
        : '$greeting.';
    final date = DateFormat(
      'EEEE · d MMMM',
      l10n.localeName,
    ).format(DateTime.now()).toUpperCase();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return SizedBox(
      height: 330,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CoverImage(imageUrl: _heroImageUrl(DateTime.now().hour), palette: 0),
          // Üstte hafif, altta güçlü karartma — ikon/metin okunabilirliği.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.30),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.62),
                ],
                stops: const [0.0, 0.44, 1.0],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'ilnd.',
                        style: AppTextStyles.display(
                          fontSize: 19,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      if (streak > 0) ...[
                        Semantics(
                          label: l10n.profileStatStreak,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.85),
                                width: 1.6,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$streak',
                              style: AppTextStyles.body(
                                fontSize: 13,
                                color: Colors.white,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // ILND girişi buradan ALINDI: ekleme günlük kullanımın
                      // merkezi olduğu için alt navigasyonun orta halkasına
                      // taşındı (başparmak menzili). Hero'da iki halka birden
                      // durması "hangisi hangisi" sorusunu doğuruyordu.
                      _HeroIconButton(
                        icon: p.isDark
                            ? Icons.wb_sunny_outlined
                            : Icons.nightlight_outlined,
                        label: l10n.a11yToggleTheme,
                        onTap: () {
                          ref.read(themeModeProvider.notifier).state = p.isDark
                              ? Brightness.light
                              : Brightness.dark;
                        },
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        label: l10n.a11yOpenProfile,
                        child: Pressable(
                          onTap: () => context.go(routeProfile),
                          child: UserAvatar(
                            size: 34,
                            initial: initial,
                            p: p,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    date,
                    style: AppTextStyles.label(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.85),
                    ).copyWith(letterSpacing: 2),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    who,
                    style: AppTextStyles.display(
                      fontSize: 34,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  // Streak satiri hero'nun icinde yasar (handoff §1): ayri bir
                  // banner degil, selamlamanin devami. Dil gurur odakli,
                  // sucluluk yok — StreakCopy zaten bunu garantiliyor.
                  if (streakLine != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      streakLine,
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Pressable(
        onTap: onTap,
        // Görsel çap 34 ama dokunma hedefi 44 olmalı (Apple HIG / Material
        // 48dp). Halka aynı boyutta kalır, tıklanabilir alan büyür.
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.75),
                  width: 1.2,
                ),
              ),
              child: Icon(icon, size: 17, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ekranın kapanış satırları: gece ritüeli daveti ve haftalık kart.
/// Handoff §1 "üç sessiz satır" — kart değil, hairline ile ayrılmış satırlar.
/// Saat parametreyle gelir (test edilebilirlik, `_heroImageUrl` deseni).
class _QuietRows extends ConsumerWidget {
  const _QuietRows({required this.p, required this.hour});
  final AppPalette p;
  final int hour;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final doneTonight = ref.watch(sleepRitualDoneTonightProvider);
    // Gece satırı yalnız akşam penceresinde ve bu gece yapılmadıysa çıkar.
    // Tasarımda üç satır da hep görünür ama prototip tek bir ana bakıyor;
    // sabah 9'da "gece ritüeline hazır mısın?" demek yanlış olurdu.
    final showRitual = isSleepRitualWindow(hour) && !doneTonight;

    return Column(
      children: [
        _Hairline(p: p),
        if (showRitual)
          _QuietRow(
            p: p,
            dotColor: p.amber,
            title: l10n.sleepRitualHomeCardTitle,
            subtitle: l10n.sleepRitualHomeCardSubtitle,
            onTap: () => context.push(routeSleepRitual),
          ),
        _QuietRow(
          p: p,
          dotColor: p.accent,
          title: l10n.takipTitle,
          subtitle: l10n.homeTrackRowSubtitle,
          onTap: () => context.push(routeTakip),
        ),
        _QuietRow(
          p: p,
          dotColor: p.text,
          title: l10n.homeWeeklyCardRowTitle,
          subtitle: l10n.homeWeeklyCardRowSubtitle,
          onTap: () => context.push(routeStreakCard),
        ),
      ],
    );
  }
}

class _QuietRow extends StatelessWidget {
  const _QuietRow({
    required this.p,
    required this.dotColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final AppPalette p;
  final Color dotColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.heading(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: p.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.body(
                          fontSize: 12,
                          color: p.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: p.textMuted),
              ],
            ),
          ),
          _Hairline(p: p),
        ],
      ),
    );
  }
}

/// Bugün'deki ada bloğu — etiket + yüzey. Yüzey Adan ekranıyla aynı
/// widget'tır (AdanCanvas): illüstrasyon geldiğinde iki yer birden değişir.
class _AdanBlock extends ConsumerWidget {
  const _AdanBlock({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state =
        ref.watch(islandStateProvider).valueOrNull ?? const IslandState();
    return Pressable(
      onTap: () => context.push(routeAdan),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adanLabel,
            style: AppTextStyles.sectionLabel(color: p.textMuted),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 150,
            child: AdanCanvas(state: state, p: p),
          ),
        ],
      ),
    );
  }
}

/// 0.5px ayırıcı — bölümleri kart yerine bu ayırır (DESIGN_SYSTEM §7.1).
class _Hairline extends StatelessWidget {
  const _Hairline({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context) => Container(height: 0.5, color: p.border);
}

// ─── Mood check-in ────────────────────────────────────────────────────────────

class _MoodCheckIn extends ConsumerStatefulWidget {
  const _MoodCheckIn({required this.p});
  final AppPalette p;

  @override
  ConsumerState<_MoodCheckIn> createState() => _MoodCheckInState();
}

class _MoodCheckInState extends ConsumerState<_MoodCheckIn> {
  static const _moods = [
    ('☾', 'calm'),
    ('◍', 'good'),
    ('◐', 'okay'),
    ('✦', 'tired'),
    ('☁', 'hard'),
  ];

  int? _selected;

  String _moodLabel(AppLocalizations l10n, String key) {
    switch (key) {
      case 'calm':
        return l10n.homeMoodCalm;
      case 'good':
        return l10n.homeMoodGood;
      case 'okay':
        return l10n.homeMoodOkay;
      case 'tired':
        return l10n.homeMoodTired;
      case 'hard':
        return l10n.homeMoodHard;
      default:
        return key;
    }
  }

  // Show the pick landing (fill + scale) before handing off to chat — a
  // beat of acknowledgment instead of an instant, jarring navigation.
  // Bir kez cevaplanınca günün geri kalanında tekrar sorulmaz (todaysMoodProvider).
  Future<void> _select(int index, AppLocalizations l10n) async {
    if (_selected != null) return;
    setState(() => _selected = index);
    final moodKey = _moods[index].$2;
    await ref.read(todaysMoodProvider.notifier).record(moodKey);
    unawaited(
      ref
          .read(ilndMemoryProvider.notifier)
          .addNote('Bugünkü ruh hali: ${_moodLabel(l10n, moodKey)}'),
    );
    await Future.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    context.push(routeChat);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = widget.p;
    final todaysMood = ref.watch(todaysMoodProvider);

    if (todaysMood != null) {
      final moodEntry = _moods.firstWhere(
        (m) => m.$2 == todaysMood,
        orElse: () => _moods.first,
      );
      // Cevaplandiktan sonra tek sessiz satir kalir — kutu yok.
      return Row(
        children: [
          Text(moodEntry.$1, style: TextStyle(fontSize: 17, color: p.accent)),
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

    // Kart degil: soru + daireler dogrudan zeminde durur. Ayrimi kenarlik
    // degil bosluk ve hairline kurar (DESIGN_SYSTEM §7.1, kutu hastaligi).
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.homeMoodQuestion,
            style: AppTextStyles.body(fontSize: 13, color: p.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final (index, m) in _moods.indexed)
                Pressable(
                  onTap: () => _select(index, l10n),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _selected == index
                              ? p.accentSoft
                              : Colors.transparent,
                          border: Border.all(
                            color: _selected == index ? p.accent : p.border,
                            width: _selected == index ? 1.5 : 0.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: AnimatedScale(
                          scale: _selected == index ? 1.2 : 1.0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          child: Text(
                            m.$1,
                            style: TextStyle(
                              fontSize: 17,
                              color: _selected == index ? p.accent : p.text,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _moodLabel(l10n, m.$2),
                        style:
                            AppTextStyles.body(
                              fontSize: 9.5,
                              color: _selected == index
                                  ? p.accent
                                  : p.textMuted,
                            ).copyWith(
                              fontWeight: _selected == index
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.p});
  final String text;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    // Büyük harf .arb'den gelir, koddan değil (turkish_copy_test).
    return Text(text, style: AppTextStyles.sectionLabel(color: p.textMuted));
  }
}

// ─── Daily read card — single editorial feature ───────────────────────────────

class _DailyReadCard extends StatelessWidget {
  const _DailyReadCard({required this.article, required this.p});
  final Article article;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Pressable(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ArticleDetailScreen(article: article),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        child: SizedBox(
          height: 300,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CoverImage(
                imageUrl: article.imageUrl,
                palette: article.category.palette,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                // Kart sabit 300px ama içerik değişken: makale her gün döner
                // ve uzun başlıklı bir gün geldiğinde taşıyordu (dar ekranda
                // sarma + serif satır yüksekliği). Sert Kural #14'ün aynısı:
                // sabit boyutlu bir yüzey esnek içerik varsayamaz.
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        article.category.tag.toUpperCase(),
                        style: AppTextStyles.label(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: Text(
                        article.title,
                        style: AppTextStyles.display(
                          fontSize: 30,
                          color: Colors.white,
                          height: 1.05,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: Text(
                        article.excerpt,
                        style: AppTextStyles.body(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.homeReadTimeArrow(article.readTime),
                      style: AppTextStyles.body(
                        fontSize: 11.5,
                        color: Colors.white,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
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
/// henüz yüklenmediyse hiçbir şey çizilmez — boş bir "planın" başlığı olmayan
/// bir özelliğin sözünü vermek olurdu.
class _ActivePlanRow extends ConsumerWidget {
  const _ActivePlanRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(activePlanProvider);
    if (plan == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final localized = plan.forLocale(l10n.localeName);
    final progress =
        ref.watch(planProgressProvider(plan.id)).valueOrNull ??
        const PlanProgress();
    final next = progress.nextDay(localized);
    if (next == null) return const SizedBox.shrink(); // plan bitti

    final dayNumber = localized.days.indexWhere((d) => d.id == next.id) + 1;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Pressable(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => PlanDetailScreen(plan: plan)),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radius),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.homeActivePlanLabel,
                      style: AppTextStyles.sectionLabel(color: p.accent),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${l10n.planDayLabel(dayNumber)}: ${next.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(
                        fontSize: 15,
                        color: p.text,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.planProgress(
                        progress.doneCountIn(localized),
                        localized.lengthDays,
                      ),
                      style: AppTextStyles.body(
                        fontSize: 11.5,
                        color: p.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: p.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
