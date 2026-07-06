import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
import 'package:ilnd_app/core/widgets/breath_ring.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Topluluk sekmesi v1 — vizyonun (Circle + Etkinlik) yuvası.
///
/// Gerçek etkinlik listesi + RSVP, Firestore `events` şemasıyla ayrı bir
/// architecture:L işi (docs/PRODUCT_ROADMAP.md NEXT-2). v1 bilinçli olarak
/// tek şey yapar: sekmeyi meşru kılar ve referral döngüsüne bağlanır —
/// boş bir "yakında" ekranı değil, bir davet.
class TopulukScreen extends ConsumerWidget {
  const TopulukScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);

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
                const SizedBox(height: 48),
                Entrance(index: 2, child: Center(child: BreathRing(size: 96))),
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
                  child: Pressable(
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
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
