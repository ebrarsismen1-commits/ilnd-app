import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
import 'package:ilnd_app/core/widgets/cover_image.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/explore/article_detail_screen.dart';
import 'package:ilnd_app/features/explore/article_model.dart';
import 'package:ilnd_app/features/home/home_provider.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              SliverToBoxAdapter(child: _TopBar(name: name, p: p)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding, 8, AppSpacing.screenPadding, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate.fixed([
                    Entrance(index: 0, child: _GreetingHero(name: name, memory: memory, p: p)),
                    const SizedBox(height: 22),
                    Entrance(index: 1, child: _MoodCheckIn(p: p)),
                    const SizedBox(height: 32),
                    Entrance(index: 2, child: _SectionTitle('bugünün okuması', p: p)),
                    const SizedBox(height: 12),
                    Entrance(index: 3, child: _DailyReadCard(article: read, p: p)),
                    const SizedBox(height: 32),
                    Entrance(index: 4, child: _SectionTitle('bugünün niyeti', p: p)),
                    const SizedBox(height: 12),
                    Entrance(index: 5, child: _DailyIntentionSection()),
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

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.name, required this.p});
  final String name;
  final AppPalette p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding, 16, AppSpacing.screenPadding, 0),
      child: Row(
        children: [
          Text('ilnd', style: AppTextStyles.display(fontSize: 22, color: p.text)),
          const Spacer(),
          Pressable(
            onTap: () {
              final mode = ref.read(themeModeProvider.notifier);
              mode.state = p.isDark ? Brightness.light : Brightness.dark;
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: p.surface,
                shape: BoxShape.circle,
                border: Border.all(color: p.border, width: 0.5),
              ),
              child: Icon(
                p.isDark ? Icons.wb_sunny_outlined : Icons.nightlight_outlined,
                size: 18,
                color: p.isDark ? p.amber : p.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Pressable(
            onTap: () => context.go(routeProfile),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(initial,
                  style: AppTextStyles.body(fontSize: 15, color: p.onAccent)
                      .copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Greeting hero — ILND speaks first ────────────────────────────────────────

class _GreetingHero extends StatelessWidget {
  const _GreetingHero({required this.name, required this.memory, required this.p});
  final String name;
  final IlndMemory memory;
  final AppPalette p;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 6) return 'iyi geceler';
    if (h < 12) return 'günaydın';
    if (h < 18) return 'iyi günler';
    return 'iyi akşamlar';
  }

  String get _proactive {
    if (memory.goals.isNotEmpty) {
      return '“${memory.goals.first}” için bugün küçük bir şey ayarlayalım mı?';
    }
    if (memory.recentNotes.isNotEmpty) {
      return 'dün konuştuklarımızı düşündüm. bugün nasılsın?';
    }
    return 'içinden ne geçiyorsa, buradayım.';
  }

  @override
  Widget build(BuildContext context) {
    final who = name.isNotEmpty ? '$_greeting,\n$name.' : '$_greeting.';
    return Pressable(
      onTap: () => context.push(routeChat),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(who, style: AppTextStyles.display(fontSize: 40, color: p.text, height: 1.05)),
          const SizedBox(height: 14),
          // ILND's proactive, memory-aware line
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border, width: 0.5),
            ),
            child: Row(
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
                  child: Text(_proactive,
                      style: AppTextStyles.body(fontSize: 14, color: p.text, height: 1.4)),
                ),
                Icon(Icons.arrow_forward_rounded, size: 18, color: p.textMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mood check-in ────────────────────────────────────────────────────────────

class _MoodCheckIn extends StatelessWidget {
  const _MoodCheckIn({required this.p});
  final AppPalette p;

  static const _moods = [
    ('☾', 'sakin'),
    ('◍', 'iyi'),
    ('◐', 'idare'),
    ('✦', 'yorgun'),
    ('☁', 'zor'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('bugün nasıl hissediyorsun?',
            style: AppTextStyles.body(fontSize: 13, color: p.textMuted)),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final m in _moods) ...[
              Expanded(
                child: Pressable(
                  onTap: () => context.push(routeChat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.border, width: 0.5),
                    ),
                    child: Column(
                      children: [
                        Text(m.$1, style: TextStyle(fontSize: 20, color: p.text)),
                        const SizedBox(height: 5),
                        Text(m.$2,
                            style: AppTextStyles.body(fontSize: 10, color: p.textMuted)),
                      ],
                    ),
                  ),
                ),
              ),
              if (m != _moods.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
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
    return Text(text, style: AppTextStyles.display(fontSize: 22, color: p.text));
  }
}

// ─── Daily read card — single editorial feature ───────────────────────────────

class _DailyReadCard extends StatelessWidget {
  const _DailyReadCard({required this.article, required this.p});
  final Article article;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ArticleDetailScreen(article: article)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        child: SizedBox(
          height: 300,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CoverImage(imageUrl: article.imageUrl, palette: article.category.palette),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(article.category.tag.toUpperCase(),
                          style: AppTextStyles.label(fontSize: 10, color: Colors.white)),
                    ),
                    const SizedBox(height: 12),
                    Text(article.title,
                        style: AppTextStyles.display(fontSize: 30, color: Colors.white, height: 1.05)),
                    const SizedBox(height: 8),
                    Text(article.excerpt,
                        style: AppTextStyles.body(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    Text('${article.readTime} okuma  →',
                        style: AppTextStyles.body(fontSize: 12, color: Colors.white)
                            .copyWith(fontWeight: FontWeight.w600)),
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
    final p = ref.watch(paletteProvider);
    final intention = ref.watch(dailyIntentionProvider);
    final hasIntention = intention != null && intention.isNotEmpty;

    if (hasIntention && !_editing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(intention,
              style: AppTextStyles.display(
                  fontSize: 20, color: p.text, fontWeight: FontWeight.w500, height: 1.3)),
          const SizedBox(height: 8),
          Pressable(
            onTap: () => _startEditing(intention),
            child: Text('düzenle',
                style: AppTextStyles.body(fontSize: 12, color: p.accent)
                    .copyWith(fontWeight: FontWeight.w500)),
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
            border: Border.all(color: _editing ? p.accent : p.border, width: _editing ? 1 : 0.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _controller,
            autofocus: _editing,
            textCapitalization: TextCapitalization.sentences,
            maxLines: null,
            style: AppTextStyles.body(fontSize: 16, height: 1.5, color: p.text),
            decoration: InputDecoration(
              hintText: 'bugün ne olmak istiyorsun?',
              hintStyle: AppTextStyles.display(
                  fontSize: 16, fontWeight: FontWeight.w400, color: p.textMuted),
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
          child: Text('kaydet',
              style: AppTextStyles.label(fontSize: 13, color: p.accent)
                  .copyWith(letterSpacing: 0.2)),
        ),
      ],
    );
  }
}
