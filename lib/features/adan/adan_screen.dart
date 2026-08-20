import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/adan/adan_model.dart';
import 'package:ilnd_app/features/adan/adan_repository.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Adan — ilerleme sayı değil yer olarak (ADR-0006, handoff §7).
///
/// Ada illüstrasyonu bu turda YOK (owner kararı): görsel alanı sade bir
/// yüzey olarak durur. Öğe listesi ve kazanım mantığı görselsiz de tam
/// çalışır; illüstrasyon geldiğinde yalnız bu kutunun içi değişir.
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

    return Scaffold(
      backgroundColor: p.base,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            8,
            AppSpacing.screenPadding,
            40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Pressable(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10, bottom: 4),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 26,
                        color: p.textMuted,
                      ),
                    ),
                  ),
                  Text(
                    l10n.adanTitle,
                    style: AppTextStyles.screenTitle(
                      color: p.text,
                      fontSize: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Entrance(
                index: 0,
                child: AdanCanvas(state: state, p: p, showWordmark: false),
              ),
              const SizedBox(height: 24),
              Entrance(
                index: 1,
                child: Text(
                  l10n.adanLead,
                  style: AppTextStyles.heading(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: p.text,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Entrance(
                index: 2,
                child: Text(
                  l10n.adanBody,
                  style: AppTextStyles.body(
                    fontSize: 13,
                    color: p.textMuted,
                    height: 1.55,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                l10n.adanItemsLabel,
                style: AppTextStyles.sectionLabel(color: p.textMuted),
              ),
              const SizedBox(height: 10),
              for (final (i, item) in kIslandItems.indexed)
                Entrance(
                  index: 3 + i,
                  child: _ItemRow(item: item, state: state, p: p),
                ),
              const SizedBox(height: 18),
              if (state.nextItem case final next?)
                Text(
                  l10n.adanNextNote(
                    adanItemName(l10n, next.id),
                    adanItemHow(l10n, next.id),
                  ),
                  style: AppTextStyles.body(
                    fontSize: 12.5,
                    color: p.textMuted,
                    height: 1.55,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ada yüzeyi. İllüstrasyon gelene kadar sade bir alan — kazanılan öğe
/// sayısını taşır. Boş bir çerçeveye "ada" demek yerine ne olduğunu söyler.
class AdanCanvas extends StatelessWidget {
  const AdanCanvas({
    super.key,
    required this.state,
    required this.p,
    this.showWordmark = true,
  });

  final IslandState state;
  final AppPalette p;

  /// Kartın sol üstündeki serif `adan.` imzası. Adan ekranında başlık zaten
  /// aynı kelimeyi söylüyor, orada kapatılır — Bugün'de ise kartı adlandıran
  /// tek şey bu (prototip §1: sol üstte Noto Serif 19 "adan.").
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final next = state.nextItem;
    return Container(
      height: 330,
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (showWordmark)
            Text(
              l10n.adanTitle,
              style: AppTextStyles.heading(fontSize: 19, color: p.accent),
            )
          else
            const SizedBox.shrink(),
          Text(
            next == null
                ? '${state.earnedCount}'
                : (state.earnedCount == 0
                      ? l10n.adanEmptyProgress
                      : l10n.adanProgress(
                          state.earnedCount,
                          adanItemName(l10n, next.id),
                        )),
            style: AppTextStyles.body(fontSize: 11.5, color: p.accent),
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              // Kazanılmış öğe dolu çip, kilitli olan kesikli kenarlık —
              // tasarımın kendi ayrımı.
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: earned ? p.accentSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: earned ? null : Border.all(color: p.border, width: 1),
                ),
                alignment: Alignment.center,
                child: Icon(
                  earned ? Icons.check_rounded : Icons.lock_outline_rounded,
                  size: 16,
                  color: earned ? p.accent : p.textMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adanItemName(l10n, item.id),
                      style: AppTextStyles.heading(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w500,
                        color: earned ? p.text : p.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      earned ? '$how · ${l10n.adanEarnedSuffix}' : how,
                      style: AppTextStyles.body(
                        fontSize: 11.5,
                        color: p.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                earned ? l10n.adanStateOpen : l10n.adanStateLocked,
                style: AppTextStyles.mono(
                  fontSize: 9.5,
                  color: earned ? p.accent : p.textMuted,
                ),
              ),
            ],
          ),
        ),
        Container(height: 0.5, color: p.border),
      ],
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
