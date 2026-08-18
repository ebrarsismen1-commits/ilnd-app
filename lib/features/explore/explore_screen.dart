import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
import 'package:ilnd_app/core/widgets/breath_animation.dart';
import 'package:ilnd_app/core/widgets/breath_ring.dart';
import 'package:ilnd_app/core/widgets/cover_image.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/core/repositories/explore_repository.dart';
import 'package:ilnd_app/core/repositories/movement_repository.dart';
import 'package:ilnd_app/core/repositories/plans_repository.dart';
import 'package:ilnd_app/features/explore/article_detail_screen.dart';
import 'package:ilnd_app/features/explore/article_model.dart';
import 'package:ilnd_app/features/movement/movement_program.dart';
import 'package:ilnd_app/features/movement/movement_program_screen.dart';
import 'package:ilnd_app/features/plans/plan_shelf.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

// ─── Filter ───────────────────────────────────────────────────────────────────

enum _Filter { hepsi, wellness, tarifler, yazilar }

extension _FilterX on _Filter {
  String label(AppLocalizations l10n) => switch (this) {
    _Filter.hepsi => l10n.exploreFilterAll,
    _Filter.wellness => l10n.exploreFilterWellness,
    _Filter.tarifler => l10n.exploreFilterRecipes,
    _Filter.yazilar => l10n.exploreFilterArticles,
  };

  bool matches(Article a) => switch (this) {
    _Filter.hepsi => true,
    _Filter.wellness => a.category == ArticleCategory.wellness,
    _Filter.tarifler => a.category == ArticleCategory.tarif,
    _Filter.yazilar => a.category == ArticleCategory.yazi,
  };
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  _Filter _selected = _Filter.hepsi;

  void _open(Article a) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (ctx, anim, _) => ArticleDetailScreen(article: a),
        transitionsBuilder: (ctx, anim, _, child) {
          final c = CurvedAnimation(parent: anim, curve: Curves.easeOutQuart);
          return FadeTransition(
            opacity: c,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(c),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 380),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final fetched = ref.watch(articlesProvider).valueOrNull;
    // Uygulama diline göre sürüm seç (EN çevirisi olmayan alan TR'ye düşer).
    final allArticles =
        ((fetched == null || fetched.isEmpty) ? kArticles : fetched)
            .map((a) => a.forLocale(l10n.localeName))
            .toList();
    // Handoff §2: ekranin tek buyuk ani kapak, geri kalan HEPSI tek liste.
    // Eski duzende araya bir de yatay "one cikanlar" seridi giriyordu —
    // ayni icerigi ikinci bir bicimde gostermek listeyi zayiflatiyordu.
    final hero = allArticles.isNotEmpty ? allArticles.first : null;
    final rest = allArticles.length > 1 ? allArticles.sublist(1) : <Article>[];
    final filtered = rest.where((a) => _selected.matches(a)).toList();
    // Yalnız oynatılabilir seansı olan programlar (ADR-0004). Makalelerdeki
    // kArticles gibi bir offline yedeği YOK: video içeriğinin yerel karşılığı
    // olamaz, içerik gelmeden raf da olmaz.
    final movementPrograms = ref
        .watch(publishableMovementProgramsProvider)
        .map((m) => m.forLocale(l10n.localeName))
        .toList();
    // Planlar da aynı ilkeye tabi (ADR-0005): günü eksik ya da uzunluğu
    // tanımsız plan listeye hiç girmez, liste boşsa raf hiç çizilmez.
    // Yerelleştirme kart/detay içinde yapılır — sıralama ve ilerleme
    // eşleşmesi plan id'si üzerinden yürüdüğü için burada ham liste taşınır.
    final plans = ref.watch(publishablePlansProvider);

    return Scaffold(
      backgroundColor: p.base,
      body: AnimatedBackground(
        palette: p,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── Header ────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    28,
                    AppSpacing.screenPadding,
                    6,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.exploreTitle,
                              style: AppTextStyles.display(
                                fontSize: 30,
                                color: p.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.exploreSubtitle,
                              style: AppTextStyles.body(
                                fontSize: 13,
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

              // ── Hero card ─────────────────────────────────────────────────
              if (hero != null) ...[
                SliverToBoxAdapter(
                  child: Entrance(
                    index: 0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPadding,
                      ),
                      child: _HeroCard(article: hero, p: p, onTap: _open),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],

              // ── Ritüeller (eski emoji "stories" şeridinin yerine — vizyon
              // kararı: her kart gerçek bir deneyime açılır, dekoratif emoji
              // dairesi değil) ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _RitualsRow(articles: allArticles, p: p, onOpen: _open),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // ── Planlar (ADR-0005). Hareket rafının üstünde: plan bir
              // taahhüt, tek seans bir deneme — kullanıcıya önce taahhüdü
              // gösteriyoruz ────────────────────────────────────────────────
              if (plans.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: PlanShelf(plans: plans, p: p),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ],

              // ── Hareket programları (ADR-0004) — vizyonun "grid'e yeni
              // içerik tipleri raf olarak girer" maddesi. Yayınlanabilir
              // program yoksa raf HİÇ çizilmez: boş bir raf, olmayan bir
              // özelliğin sözünü vermek olurdu ────────────────────────────
              if (movementPrograms.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _MovementShelf(programs: movementPrograms, p: p),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ],

              // ── Günün alıntısı ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Entrance(
                  index: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPadding,
                    ),
                    child: _QuoteBanner(p: p),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    0,
                    AppSpacing.screenPadding,
                    12,
                  ),
                  child: Text(
                    l10n.exploreMoreLabel,
                    style: AppTextStyles.sectionLabel(color: p.textMuted),
                  ),
                ),
              ),

              // ── Etiket rayı (handoff §2) ─────────────────────────────
              // Pill'ler LİSTENİN yanında durur, başlığın altında değil:
              // handoff'ta araya yalnız kapak giriyordu, bizde dört raf daha
              // var — filtreyi listeden koparmak "bastım, hiçbir şey
              // değişmedi" hissi veriyor.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    0,
                    AppSpacing.screenPadding,
                    14,
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _Filter.values.map((f) {
                      final active = _selected == f;
                      return Pressable(
                        onTap: () => setState(() => _selected = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: active ? p.accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: active ? p.accent : p.border,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            f.label(l10n),
                            style: AppTextStyles.label(
                              fontSize: 10.5,
                              color: active ? p.onAccent : p.textMuted,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── Feed ──────────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  0,
                  AppSpacing.screenPadding,
                  40,
                ),
                sliver: filtered.isEmpty
                    ? const SliverToBoxAdapter(child: SizedBox.shrink())
                    : SliverList.separated(
                        itemCount: filtered.length,
                        // Kart yok; satirlari 0.5px hairline ayirir.
                        separatorBuilder: (ctx0, i0) =>
                            Container(height: 0.5, color: p.border),
                        itemBuilder: (context, i) => Entrance(
                          index: i,
                          delayStep: const Duration(milliseconds: 60),
                          child: _FeedRow(
                            article: filtered[i],
                            p: p,
                            onTap: _open,
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

// ─── Hareket programları ──────────────────────────────────────────────────────

/// Video programlarının yatay rafı (ADR-0004). Kart dokunuşu program detayına
/// gider; kilitli programda paywall'ı detay ekranı açar (tek kapı).
class _MovementShelf extends StatelessWidget {
  const _MovementShelf({required this.programs, required this.p});

  final List<MovementProgram> programs;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          child: Text(
            l10n.movementShelfLabel,
            style: AppTextStyles.label(fontSize: 11.5, color: p.accent),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 176,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
            ),
            itemCount: programs.length,
            separatorBuilder: (ctx0, i0) => const SizedBox(width: 12),
            itemBuilder: (context, i) => Entrance(
              index: i,
              child: _MovementCard(program: programs[i], p: p, l10n: l10n),
            ),
          ),
        ),
      ],
    );
  }
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({
    required this.program,
    required this.p,
    required this.l10n,
  });

  final MovementProgram program;
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MovementProgramScreen(program: program),
        ),
      ),
      child: SizedBox(
        // Genişlik sabit değil, viewport'a göre kırpılır: dar ekranda kart
        // taşmasın (Sert Kural #14'ün öğrettiği esneklik).
        width: (MediaQuery.sizeOf(context).width * 0.62).clamp(200.0, 260.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CoverImage(imageUrl: program.coverUrl, palette: 0),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black54],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.play_circle_outline_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l10n.movementSessionCount(
                                program.playableSessions.length,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.label(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (program.premium)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: p.accent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                l10n.movementPremiumBadge,
                                style: AppTextStyles.label(
                                  fontSize: 10,
                                  color: p.onAccent,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              program.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(fontSize: 13, color: p.text),
            ),
            Text(
              [
                MovementProgramScreen.levelLabel(program.level, l10n),
                if (program.totalMinutes > 0)
                  l10n.movementMinutes(program.totalMinutes),
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(fontSize: 11.5, color: p.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ritüeller ────────────────────────────────────────────────────────────────

/// Her kart gerçek bir deneyime açılır: nefes → interaktif nefes ekranı,
/// diğerleri → içerik hattındaki (content/articles.json) eşleşen makale.
/// Eşleşen makale yoksa (içerik henüz girilmemişse) kart sessizce gizlenir —
/// asla ölü bir dokunma hedefi göstermeyiz.
class _RitualsRow extends StatelessWidget {
  const _RitualsRow({
    required this.articles,
    required this.p,
    required this.onOpen,
  });
  final List<Article> articles;
  final AppPalette p;
  final void Function(Article) onOpen;

  /// Anahtar kelime BAŞLIKTA değil ID'de aranır — id'ler dil değişse de
  /// sabittir (EN kullanıcıda 'hareket' başlığı çevrilince kart kaybolmasın).
  Article? _byKeyword(String keyword) {
    for (final a in articles) {
      if (a.id.contains(keyword)) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final movementArticle = _byKeyword('hareket');

    final cards = <_RitualCard>[
      _RitualCard(
        title: l10n.exploreRitualBreathTitle,
        fill: p.accent,
        onLight: true,
        trailing: const BreathRing(size: 22),
        onTap: () => Navigator.of(context).push(
          PageRouteBuilder<void>(
            pageBuilder: (ctx, anim, _) => BreathScreen(p: p),
            transitionsBuilder: (ctx, anim, _, child) {
              final c = CurvedAnimation(
                parent: anim,
                curve: Curves.easeOutCubic,
              );
              return FadeTransition(
                opacity: c,
                child: ScaleTransition(
                  scale: Tween(begin: 0.92, end: 1.0).animate(c),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 350),
          ),
        ),
      ),
      // Gece ritüeli artık makale değil, interaktif adım adım deneyim —
      // içerikten bağımsız olduğu için her zaman görünür.
      _RitualCard(
        title: l10n.exploreRitualSleepTitle,
        fill: p.surfaceStrong,
        onLight: false,
        onTap: () => context.push(routeSleepRitual),
      ),
      if (movementArticle != null)
        _RitualCard(
          title: l10n.exploreRitualMovementTitle,
          fill: p.amber,
          onLight: true,
          onTap: () => onOpen(movementArticle),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          child: Text(
            l10n.exploreRitualsLabel,
            style: AppTextStyles.label(fontSize: 11.5, color: p.accent),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
            ),
            itemCount: cards.length,
            separatorBuilder: (ctx0, i0) => const SizedBox(width: 8),
            itemBuilder: (context, i) => cards[i],
          ),
        ),
      ],
    );
  }
}

class _RitualCard extends StatelessWidget {
  const _RitualCard({
    required this.title,
    required this.fill,
    required this.onLight,
    required this.onTap,
    this.trailing,
  });
  final String title;
  final Color fill;
  final bool onLight;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textColor = onLight ? Colors.white : AppTextStyles.body().color!;
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 118,
        height: 108,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _RitualTitle(title: title, color: textColor),
            trailing ??
                Icon(
                  Icons.arrow_outward_rounded,
                  size: 15,
                  color: onLight
                      ? Colors.white.withValues(alpha: 0.85)
                      : textColor.withValues(alpha: 0.6),
                ),
          ],
        ),
      ),
    );
  }
}

/// "2 dk nefes", "gece ritüeli" gibi iki kelimelik başlıkları serif +
/// ikinci kelime italik olacak şekilde böler (DESIGN_SYSTEM §2 imzası) —
/// bu üç başlık bizim kendi kopyamız olduğu için (dinamik makale değil)
/// italik-kelime-vurgusu güvenle uygulanabilir.
class _RitualTitle extends StatelessWidget {
  const _RitualTitle({required this.title, required this.color});
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final words = title.split(' ');
    if (words.length < 2) {
      return Text(
        title,
        style: AppTextStyles.display(fontSize: 15, color: color, height: 1.15),
      );
    }
    return Text.rich(
      TextSpan(
        style: AppTextStyles.display(fontSize: 15, color: color, height: 1.15),
        children: [
          TextSpan(text: '${words.sublist(0, words.length - 1).join(' ')} '),
          TextSpan(
            text: words.last,
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

// ─── Hero card ────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.article,
    required this.p,
    required this.onTap,
  });
  final Article article;
  final AppPalette p;
  final void Function(Article) onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => onTap(article),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        child: SizedBox(
          // Ekranin tek buyuk ani (handoff §2): 3:4'e yakin, dolu bir kapak.
          height: 400,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // fotoğraf
              CoverImage(
                imageUrl: article.imageUrl,
                palette: article.category.palette,
              ),
              // gradient overlay
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: const [0.3, 0.6, 1.0],
                  ),
                ),
              ),
              // içerik
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // üst: kategori chip
                    Row(children: [_CategoryChip(article.category)]),
                    // alt: başlık + excerpt
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article.title,
                          style: AppTextStyles.display(
                            fontSize: 32,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          article.excerpt,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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

// ─── Quote banner ─────────────────────────────────────────────────────────────

class _QuoteBanner extends StatelessWidget {
  const _QuoteBanner({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            p.accent.withValues(alpha: 0.12),
            p.amber.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.accent.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        children: [
          Text(
            '✨',
            style: TextStyle(
              fontSize: 28,
              shadows: [
                Shadow(color: p.accent.withValues(alpha: 0.4), blurRadius: 8),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.exploreQuote,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.text,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.exploreQuoteSubtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: p.textMuted,
                    height: 1.4,
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

// ─── Category chip ────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  const _CategoryChip(this.category);
  final ArticleCategory category;

  Color get _color => switch (category) {
    ArticleCategory.wellness => const Color(0xFF5B8C7B),
    ArticleCategory.tarif => const Color(0xFF34D399),
    ArticleCategory.yazi => const Color(0xFFC17A63),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        category.tag.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Feed row ─────────────────────────────────────────────────────────────────

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.article, required this.p, required this.onTap});
  final Article article;
  final AppPalette p;
  final void Function(Article) onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => onTap(article),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 68x82 dikey kucuk gorsel — kare degil, editoryal oran.
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 68,
                height: 82,
                child: CoverImage(
                  imageUrl: article.imageUrl,
                  palette: article.category.palette,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.category.tag.toUpperCase(),
                    style: AppTextStyles.label(
                      fontSize: 9.5,
                      color: p.accent,
                      letterSpacingEm: 0.12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    article.title,
                    style: AppTextStyles.heading(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w500,
                      color: p.text,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    article.readTime,
                    style: AppTextStyles.mono(
                      fontSize: 11.5,
                      color: p.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
