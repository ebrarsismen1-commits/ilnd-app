import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/utils/possessive.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/ilnd_surfaces.dart';
import 'package:ilnd_app/features/adan/adan_model.dart';
import 'package:ilnd_app/features/adan/adan_repository.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Adan (Ada tasarımı 04): ilerleme sayı değil yer olarak (ADR-0006).
///
/// Ada kartı şimdilik illüstrasyonsuz (bkz. [IslandFrame]); öğeler ve
/// kazanım mantığı değişmedi, yalnız kart olarak dizildiler.
class AdanScreen extends ConsumerStatefulWidget {
  const AdanScreen({super.key});

  @override
  ConsumerState<AdanScreen> createState() => _AdanScreenState();
}

class _AdanScreenState extends ConsumerState<AdanScreen> {
  @override
  void initState() {
    super.initState();
    // Kazanımı sunucuya hesaplatan tek yer: ekran açılışı. İdempotent
    // olduğu için tekrar çağrılması zararsız (ADR-0006).
    Future.microtask(() => ref.read(syncIslandProvider)());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final state =
        ref.watch(islandStateProvider).valueOrNull ?? const IslandState();
    final onboardingName = ref.watch(userNameProvider);
    final name = onboardingName.isNotEmpty
        ? onboardingName
        : ref.watch(ilndMemoryProvider).name;

    return Scaffold(
      backgroundColor: p.base,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            8,
            AppSpacing.screenPadding,
            40,
          ),
          children: [
            IlndPageHeader(
              p: p,
              title: l10n.adanTitle,
              subtitle: l10n.adanSubtitle,
            ),
            const SizedBox(height: 18),
            Entrance(
              index: 0,
              child: LayoutBuilder(
                builder: (context, constraints) => SizedBox(
                  height: (constraints.maxWidth / 1.34).clamp(180.0, 300.0),
                  child: AdanCanvas(state: state, p: p, showWordmark: false),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Entrance(
              index: 1,
              child: Text(
                name.isEmpty
                    ? l10n.adanTitle
                    : l10n.homeIslandOwned(possessiveName(l10n, name)),
                style: AppTextStyles.display(fontSize: 25, color: p.text),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              l10n.adanItemsTitle,
              style: AppTextStyles.serifTitle(color: p.text),
            ),
            const SizedBox(height: 12),
            for (final (i, item) in kIslandItems.indexed)
              Entrance(
                index: 2 + i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ItemRow(item: item, state: state, p: p),
                ),
              ),
            if (state.nextItem case final next?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.adanNextNote(
                    adanItemName(l10n, next.id),
                    adanItemHow(l10n, next.id),
                  ),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    fontSize: 12.5,
                    color: p.textMuted,
                    height: 1.55,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ada yüzeyi: iki tonlu çerçeve + ilerleme satırı.
///
/// Yüksekliği vermez, ebeveyninin verdiği alanı doldurur. İllüstrasyon
/// geldiğinde yalnız [IslandFrame]'in arka planı değişir; ilerleme satırı
/// ve ekran okuyucu etiketi burada kalır.
class AdanCanvas extends StatelessWidget {
  const AdanCanvas({
    super.key,
    required this.state,
    required this.p,
    this.showWordmark = true,
    this.rounded = true,
  });

  final IslandState state;
  final AppPalette p;

  /// Kartın sol üstündeki serif `adan.` imzası. Adan ekranında başlık zaten
  /// aynı kelimeyi söylüyor, orada kapatılır.
  final bool showWordmark;

  /// Kart (yuvarlak köşe) ya da tam genişlikte yer.
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final next = state.nextItem;
    // Hepsi kazanıldıysa sıradaki yok: yalnız sayı kalır.
    final progress = next == null
        ? '${state.earnedCount}'
        : (state.earnedCount == 0
              ? l10n.adanEmptyProgress
              : l10n.adanProgress(
                  state.earnedCount,
                  adanItemName(l10n, next.id),
                ));

    return IslandFrame(
      p: p,
      radius: rounded ? AppSpacing.radiusHero : 0,
      child: Stack(
        children: [
          // Etiket yalnız yüzeyin kendisinde: üstteki satırlar ekran
          // okuyucuya kendi düğümleriyle gitmeye devam etsin.
          Positioned.fill(
            child: Semantics(
              image: true,
              label: l10n.adanCanvasSemantics(state.earnedCount),
              child: const SizedBox.expand(),
            ),
          ),
          if (showWordmark)
            Positioned(
              left: 16,
              top: 13,
              child: Text(
                l10n.adanTitle,
                style: AppTextStyles.heading(fontSize: 19, color: p.text),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 13,
            child: Text(
              progress,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(fontSize: 12, color: p.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.state, required this.p});

  final IslandItem item;
  final IslandState state;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final earned = state.has(item.id);
    final how = adanItemHow(l10n, item.id);

    return IlndCard(
      p: p,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          // Kazanılmış öğe dolu karo, kilitli olan kenarlıklı: tasarımın
          // kendi ayrımı.
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: earned ? p.surfaceStrong : p.surface,
              borderRadius: BorderRadius.circular(12),
              border: earned ? null : Border.all(color: p.border),
            ),
            alignment: Alignment.center,
            child: Icon(
              earned ? Icons.check_rounded : Icons.lock_outline_rounded,
              size: 20,
              color: earned ? p.accent : p.textMuted,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  adanItemName(l10n, item.id),
                  style: AppTextStyles.rowTitle(
                    color: earned ? p.text : p.textMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  earned ? '$how · ${l10n.adanEarnedSuffix}' : how,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: p.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            earned ? l10n.adanStateOpen : l10n.adanStateLocked,
            style: AppTextStyles.mono(
              fontSize: 10,
              color: earned ? p.accent : p.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Öğe adı — kod tarafında id, kullanıcıya .arb'den (Sert Kural #1).
String adanItemName(AppLocalizations l10n, String id) => switch (id) {
  'lantern' => l10n.adanItemLantern,
  'pine' => l10n.adanItemPine,
  'oven' => l10n.adanItemOven,
  'moonlight' => l10n.adanItemMoonlight,
  'windrose' => l10n.adanItemWindrose,
  'meetingStone' => l10n.adanItemMeetingStone,
  _ => id,
};

/// "Nasıl kazanılır" satırı.
String adanItemHow(AppLocalizations l10n, String id) => switch (id) {
  'lantern' => l10n.adanHowLantern,
  'pine' => l10n.adanHowPine,
  'oven' => l10n.adanHowOven,
  'moonlight' => l10n.adanHowMoonlight,
  'windrose' => l10n.adanHowWindrose,
  'meetingStone' => l10n.adanHowMeetingStone,
  _ => id,
};
