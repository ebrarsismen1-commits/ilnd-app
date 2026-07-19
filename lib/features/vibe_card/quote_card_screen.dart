import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/repositories/referral_repository.dart';
import 'package:ilnd_app/core/services/analytics_service.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
import 'package:ilnd_app/core/widgets/ilnd_toast.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/vibe_card/quote_card_widget.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Sohbetten gelen bir ILND cümlesini kartlaştırıp paylaştırır.
/// Yapı vibe_card_screen ile aynı: RepaintBoundary yakala → PNG → share sheet.
class QuoteCardScreen extends ConsumerStatefulWidget {
  const QuoteCardScreen({super.key, required this.quote});

  final String quote;

  @override
  ConsumerState<QuoteCardScreen> createState() => _QuoteCardScreenState();
}

class _QuoteCardScreenState extends ConsumerState<QuoteCardScreen> {
  final _captureKey = GlobalKey();
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    unawaited(AnalyticsService.logEvent('quote_card_opened'));
  }

  Future<void> _share(AppLocalizations l10n) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();

      final code =
          ref.read(myGrowthProfileProvider).valueOrNull?.referralCode ?? '';
      final shareText = code.isEmpty
          ? l10n.quoteCardShareText
          : l10n.quoteCardShareTextWithCode(code);

      await Share.shareXFiles([
        XFile.fromData(bytes, mimeType: 'image/png', name: 'ilnd-quote.png'),
      ], text: shareText);

      unawaited(AnalyticsService.logEvent('quote_card_shared'));
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
    final referralCode =
        ref.watch(myGrowthProfileProvider).valueOrNull?.referralCode ?? '';
    final onboardingName = ref.watch(userNameProvider);
    final name = onboardingName.isNotEmpty
        ? onboardingName
        : ref.watch(ilndMemoryProvider).name;

    return Scaffold(
      backgroundColor: p.base,
      body: AnimatedBackground(
        palette: p,
        child: SafeArea(
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
                        child: QuoteCardWidget(
                          quote: widget.quote,
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
                  onTap: _sharing ? null : () => _share(l10n),
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
      ),
    );
  }
}
