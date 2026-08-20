import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/repositories/referral_repository.dart';
import 'package:ilnd_app/core/services/analytics_service.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/ilnd_toast.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/profile/profile_provider.dart';
import 'package:ilnd_app/features/vibe_card/card_capture.dart';
import 'package:ilnd_app/features/vibe_card/streak_card_widget.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Streak eşik kartını gösterip paylaştırır — home'daki streak satırından
/// açılır (7+ gün). Yapı diğer kart ekranlarıyla aynı.
class StreakCardScreen extends ConsumerStatefulWidget {
  const StreakCardScreen({super.key});

  @override
  ConsumerState<StreakCardScreen> createState() => _StreakCardScreenState();
}

class _StreakCardScreenState extends ConsumerState<StreakCardScreen> {
  final _captureKey = GlobalKey();
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    unawaited(AnalyticsService.logEvent('streak_card_opened'));
  }

  Future<void> _share(AppLocalizations l10n, int days) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final code =
          ref.read(myGrowthProfileProvider).valueOrNull?.referralCode ?? '';
      final ok = await shareCardCapture(
        captureKey: _captureKey,
        text: code.isEmpty
            ? l10n.streakCardShareText(days)
            : l10n.streakCardShareTextWithCode(days, code),
        fileName: 'ilnd-streak.png',
      );
      if (ok) {
        unawaited(AnalyticsService.logEvent('streak_card_shared'));
      } else if (mounted) {
        IlndToast.error(context, l10n.vibeCardShareFailed);
      }
    } catch (_) {
      if (mounted) IlndToast.error(context, l10n.vibeCardShareFailed);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final days = ref.watch(profileStatsProvider).valueOrNull?.streakDays ?? 0;
    final referralCode =
        ref.watch(myGrowthProfileProvider).valueOrNull?.referralCode ?? '';
    final onboardingName = ref.watch(userNameProvider);
    final name = onboardingName.isNotEmpty
        ? onboardingName
        : ref.watch(ilndMemoryProvider).name;

    return Scaffold(
      backgroundColor: p.base,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                8,
                4,
                AppSpacing.screenPadding,
                0,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.close_rounded, color: p.text),
                    tooltip: l10n.a11yClose,
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: RepaintBoundary(
                    key: _captureKey,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radius),
                      child: StreakCardWidget(
                        days: days,
                        userName: name,
                        p: p,
                        referralCode: referralCode,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                16,
                AppSpacing.screenPadding,
                32,
              ),
              child: Pressable(
                onTap: _sharing ? null : () => _share(l10n, days),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: p.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: _sharing
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: p.onAccent,
                          ),
                        )
                      : Text(
                          l10n.vibeCardShare,
                          style: AppTextStyles.body(
                            fontSize: 15,
                            color: p.onAccent,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
