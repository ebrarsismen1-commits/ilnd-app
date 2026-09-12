import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/breath_animation.dart';
import 'package:ilnd_app/core/widgets/breath_ring.dart';
import 'package:ilnd_app/core/widgets/cover_image.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/ilnd_surfaces.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/core/repositories/explore_repository.dart';
import 'package:ilnd_app/core/repositories/movement_repository.dart';
import 'package:ilnd_app/core/repositories/plans_repository.dart';
import 'package:ilnd_app/features/explore/article_detail_screen.dart';
import 'package:ilnd_app/features/explore/article_model.dart';
import 'package:ilnd_app/features/explore/discover_carousel.dart';
import 'package:ilnd_app/features/explore/explore_ordering.dart';
import 'package:ilnd_app/features/movement/movement_program.dart';
import 'package:ilnd_app/features/movement/movement_program_screen.dart';
import 'package:ilnd_app/features/plans/plan_shelf.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

// ─── Filter ───────────────────────────────────────────────────────────────────

/// Etiket rayı doğrudan [ArticleCategory]'yi yansıtır — "hepsi" dışında her
/// pill bir kategoriye birebir karşılık gelir. Ayrı bir filtre listesi
/// tutmak, kategori eklendiğinde iki yerin ayrışması demekti.
enum _Filter { hepsi, meditasyon, beslenme, tarif, hareket, ozBakim, gelisim }

extension _FilterX on _Filter {
  ArticleCategory? get category => switch (this) {
    _Filter.hepsi => null,
    _Filter.meditasyon => ArticleCategory.meditasyon,
    _Filter.beslenme => ArticleCategory.beslenme,
    _Filter.tarif => ArticleCategory.tarif,
    _Filter.hareket => ArticleCategory.hareket,
    _Filter.ozBakim => ArticleCategory.ozBakim,
    _Filter.gelisim => ArticleCategory.gelisim,
  };

  String label(AppLocalizations l10n) => switch (this) {
    _Filter.hepsi => l10n.exploreFilterAll,
    _Filter.meditasyon => l10n.exploreFilterMeditation,
    _Filter.beslenme => l10n.exploreFilterNutrition,
    _Filter.tarif => l10n.exploreFilterRecipes,
    _Filter.hareket => l10n.exploreFilterMovement,
    _Filter.ozBakim => l10n.exploreFilterSelfCare,
    _Filter.gelisim => l10n.exploreFilterGrowth,
  };

  bool matches(Article a) => category == null || a.category == category;
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
    // Sıra iki kez düzeltildi. Firestore `order` alanına göre veriyor ve o
    // alan EKLEME sırası: içerik kategori kategori girildiği için liste blok
    // blok diziliyordu ve kaydıran kişi tek kategoride sıkışıyordu.
    // interleaveByCategory kategorileri dönüşümlü hâle getiriyor.
    //
    // Kapak da artık filtreye tabi: önce filtreleniyor, kapak o havuzdan
    // güne göre seçiliyor. Eskiden kapak listenin ilk elemanıydı ve hangi
    // etikete basılırsa basılsın aynı içerik duruyordu.
    final ordered = interleaveByCategory(allArticles);
    // "Bugün senin için" rafının günlük dilimi. Yalnız süzülmemiş görünümde
    // çizildiği için seçim de orada anlamlı.
    final todaysPicks = _selected == _Filter.hepsi
        ? pickDaily(ordered)
        : const <Article>[];
    final railIds = todaysPicks.map((a) => a.id).toSet();
    // Büyük kapak kartı 2026-08-31'de kaldırıldı (owner kararı): ekranın
    // tek büyük anı olması gerekiyordu ama listeden bir yazıyı çekip
    // ayrıcalıklı kılıyordu ve aynı içerik iki biçimde görünüyordu.
    // Artık süzülmüş liste doğrudan çiziliyor.
    // Raftaki yazılar listeden DÜŞÜLÜR. Aynı içeriğin bir ekranda iki biçimde
    // görünmesi 2026-08-31'de büyük kapak kartının kaldırılma sebebiydi;
    // raf da aynı tuzağa düşmesin.
    final filtered = ordered
        .where((a) => _selected.matches(a) && !railIds.contains(a.id))
        .toList();
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
      body: SafeArea(
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
                            style: AppTextStyles.pageTitle(
                              color: p.text,
                              fontSize: 28,
                            ),
                          ),
                          const SizedBox(height: 4),
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

            // ── Etiket rayı ──────────────────────────────────────────────
            // Prototipteki yeri: başlığın hemen altı, kapaktan önce.
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
                  children: [
                    for (final f in _Filter.values)
                      IlndChip(
                        p: p,
                        label: f.label(l10n),
                        selected: _selected == f,
                        onTap: () => setState(() => _selected = f),
                      ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Ritüeller ────────────────────────────────────────────────
            // Yalnız "hepsi" seçiliyken çizilir (owner kararı 2026-08-31):
            // bir kategoriye süzülmüşken ritüel şeridi konuyla ilgisiz bir
            // araya girmek oluyordu.
            //
            // Büyük kapak kartı aynı kararla kaldırıldı; ekranın ilk şeyi
            // artık etiket rayı ve hemen altındaki ritüeller.
            if (_selected == _Filter.hepsi) ...[
              // ── Bugün senin için ───────────────────────────────────────
              // Kişiselleştirilmiş günlük raf, listenin ÜSTÜNDE ama etiket
              // rayının ALTINDA duruyor: rayın ekranın ilk öğesi olması
              // 2026-08-31 owner kararı, o karara dokunulmadı. Ritüeller
              // gibi yalnız süzülmemiş görünümde çizilir, çünkü bir
              // kategoriye bakan kullanıcı için kişisel gün özeti araya
              // giren bir konu değişikliği olur.
              // Ada tasarımı 08: rayın altında tek bir "başlangıç" önerisi,
              // Bugün'deki pratik kartının aynısı.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  child: PracticeCard(
                    p: p,
                    label: l10n.exploreStartLabel,
                    title: l10n.practiceBreathTitle,
                    meta: l10n.practiceBreathMeta,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BreathScreen(p: p),
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
              SliverToBoxAdapter(
                child: DiscoverCarousel(
                  title: l10n.discoverTodayTitle,
                  articles: todaysPicks,
                  p: p,
                  onOpen: _open,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
              SliverToBoxAdapter(
                child: _RitualsRow(articles: allArticles, p: p, onOpen: _open),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],

            // ── Programlar (ADR-0005) ────────────────────────────────────
            // Owner kararı: 7 ve 21 günlük programlar Keşfet'te görünür
            // olsun. Kapağın hemen altında, listeden önce: bir program
            // taahhüt, tek yazı bir okuma.
            if (plans.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: PlanShelf(plans: plans, p: p),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
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

            // ── Feed ──────────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                0,
                AppSpacing.screenPadding,
                40,
              ),
              // Boş sonuç SESSİZ kalmamalı: etikete dokunup listenin yok
              // olmasını izlemek "uygulama bozuldu" gibi okunuyor.
              sliver: filtered.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          l10n.exploreFilterEmpty,
                          style: AppTextStyles.body(
                            fontSize: 13,
                            color: p.textMuted,
                          ),
                        ),
                      ),
                    )
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
            // ── Tasarımda olmayan raflar ─────────────────────────────────
            // Ritüeller, planlar (ADR-0005) ve hareket programları (ADR-0004)
            // handoff'un hiç görmediği içerik tipleri: tasarım main'e
            // bakarak yazıldı. Ekranın tasarımdaki okunuşunu bozmasınlar
            // diye listenin ALTINA alındılar; silinmeleri söz verilmiş
            // özellikleri kaldırmak olurdu.
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
          ],
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

// ─── Category chip ────────────────────────────────────────────────────────────

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
