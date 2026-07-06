import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/ilnd/streak_copy.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/services/streak_tracker.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
import 'package:ilnd_app/core/widgets/cover_image.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/ekle/ekle_sheet.dart';
import 'package:ilnd_app/features/explore/article_detail_screen.dart';
import 'package:ilnd_app/features/explore/article_model.dart';
import 'package:ilnd_app/features/home/home_provider.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/profile/profile_provider.dart';
import 'package:ilnd_app/features/social_proof/social_proof_badge.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final onboardingName = ref.watch(userNameProvider);
    final memory = ref.watch(ilndMemoryProvider);
    final name = onboardingName.isNotEmpty ? onboardingName : memory.name;

    // Günün düzenli ama kişiye özel "okuması".
    final read = kArticles[DateTime.now().day % kArticles.length];

    return Scaffold(
      backgroundColor: p.base,
      body: AnimatedBackground(
        palette: p,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HeroHeader(name: name, p: p),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  0,
                  AppSpacing.screenPadding,
                  32,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate.fixed([
                    // Mood kartı hero fotoğrafının üzerine biner (editoryal
                    // katman) — translate görsel, layout slotu sabittir.
                    Entrance(
                      index: 0,
                      child: Transform.translate(
                        offset: const Offset(0, -26),
                        child: _MoodCheckIn(p: p),
                      ),
                    ),
                    Entrance(index: 1, child: _StreakBanner(p: p)),
                    Entrance(index: 2, child: SocialProofBadge(p: p)),
                    const SizedBox(height: 18),
                    Entrance(
                      index: 4,
                      child: _SectionTitle(l10n.homeTodaysReadTitle, p: p),
                    ),
                    const SizedBox(height: 12),
                    Entrance(
                      index: 5,
                      child: _DailyReadCard(article: read, p: p),
                    ),
                    const SizedBox(height: 32),
                    Entrance(
                      index: 6,
                      child: _SectionTitle(l10n.homeTodaysIntentionTitle, p: p),
                    ),
                    const SizedBox(height: 12),
                    Entrance(index: 7, child: _DailyIntentionSection()),
                  ]),
                ),
              ),
            ],
          ),
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
    return '${_uHero}1470252649378-9c29740c9fa8?auto=format&fit=crop&w=1200&q=70';
  }
  if (hour >= 12 && hour < 18) {
    return '${_uHero}1501854140801-50d01698950b?auto=format&fit=crop&w=1200&q=70';
  }
  return '${_uHero}1419242902214-272b3f66ee7a?auto=format&fit=crop&w=1200&q=70';
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
      height: 272,
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
                  Colors.black.withValues(alpha: 0.28),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.55),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'ilnd.',
                        style: AppTextStyles.display(
                          fontSize: 20,
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
                                fontSize: 12.5,
                                color: Colors.white,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      _HeroIconButton(
                        icon: Icons.add_rounded,
                        label: l10n.ekleTitle,
                        onTap: () => showEkleSheet(context),
                      ),
                      const SizedBox(width: 8),
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
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: p.accent,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initial,
                              style: AppTextStyles.body(
                                fontSize: 13,
                                color: p.onAccent,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
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
                      fontSize: 30,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 44),
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
    );
  }
}

// ─── Streak banner — gurur odaklı, ceza yok ───────────────────────────────────

class _StreakBanner extends ConsumerWidget {
  const _StreakBanner({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final current =
        ref.watch(profileStatsProvider).valueOrNull?.streakDays ?? 0;
    final longest = ref.watch(longestStreakProvider);
    final line = StreakCopy.line(
      current: current,
      longest: longest,
      l10n: l10n,
    );
    if (line == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          if (current > 0) const _PulsingFlame(),
          Expanded(
            child: Text(
              line,
              style: AppTextStyles.body(fontSize: 13, color: p.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// A live, active streak deserves a heartbeat instead of a static emoji —
/// slow enough (1.6s) to read as "alive", not as a loading spinner.
class _PulsingFlame extends StatefulWidget {
  const _PulsingFlame();

  @override
  State<_PulsingFlame> createState() => _PulsingFlameState();
}

class _PulsingFlameState extends State<_PulsingFlame>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);
  late final _scale = Tween(
    begin: 0.92,
    end: 1.12,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: const Text('🔥 ', style: TextStyle(fontSize: 13)),
    );
  }
}

// ─── Mood check-in ────────────────────────────────────────────────────────────

class _MoodCheckIn extends StatefulWidget {
  const _MoodCheckIn({required this.p});
  final AppPalette p;

  @override
  State<_MoodCheckIn> createState() => _MoodCheckInState();
}

class _MoodCheckInState extends State<_MoodCheckIn> {
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
  Future<void> _select(int index) async {
    if (_selected != null) return;
    setState(() => _selected = index);
    await Future.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    context.push(routeChat);
    // Reset once the mood question is shown again on return.
    setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = widget.p;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.homeMoodQuestion,
            style: AppTextStyles.body(fontSize: 12.5, color: p.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final (index, m) in _moods.indexed)
                Pressable(
                  onTap: () => _select(index),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _selected == index ? p.accentSoft : p.base,
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
                      const SizedBox(height: 5),
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

// ─── Section title ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {required this.p});
  final String text;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.display(fontSize: 22, color: p.text),
    );
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
                    Text(
                      article.title,
                      style: AppTextStyles.display(
                        fontSize: 30,
                        color: Colors.white,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.excerpt,
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.homeReadTimeArrow(article.readTime),
                      style: AppTextStyles.body(
                        fontSize: 12,
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

// ─── Daily intention section ──────────────────────────────────────────────────

class _DailyIntentionSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DailyIntentionSection> createState() =>
      _DailyIntentionSectionState();
}

class _DailyIntentionSectionState
    extends ConsumerState<_DailyIntentionSection> {
  final _controller = TextEditingController();
  bool _editing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await ref.read(dailyIntentionProvider.notifier).save(text);
    if (!mounted) return;
    _controller.clear();
    setState(() => _editing = false);
    FocusScope.of(context).unfocus();
  }

  void _startEditing(String? current) {
    _controller.text = current ?? '';
    setState(() => _editing = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final intention = ref.watch(dailyIntentionProvider);
    final hasIntention = intention != null && intention.isNotEmpty;

    if (hasIntention && !_editing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            intention,
            style: AppTextStyles.display(
              fontSize: 20,
              color: p.text,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Pressable(
            onTap: () => _startEditing(intention),
            child: Text(
              l10n.homeIntentionEdit,
              style: AppTextStyles.body(
                fontSize: 12,
                color: p.accent,
              ).copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _editing ? p.accent : p.border,
              width: _editing ? 1 : 0.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _controller,
            autofocus: _editing,
            textCapitalization: TextCapitalization.sentences,
            maxLines: null,
            style: AppTextStyles.body(fontSize: 16, height: 1.5, color: p.text),
            decoration: InputDecoration(
              hintText: l10n.homeIntentionHint,
              hintStyle: AppTextStyles.display(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: p.textMuted,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(height: 10),
        Pressable(
          onTap: _submit,
          child: Text(
            l10n.homeIntentionSave,
            style: AppTextStyles.label(
              fontSize: 13,
              color: p.accent,
            ).copyWith(letterSpacing: 0.2),
          ),
        ),
      ],
    );
  }
}
