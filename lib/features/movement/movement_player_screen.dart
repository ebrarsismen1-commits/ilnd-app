import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/repositories/movement_repository.dart';
import 'package:ilnd_app/core/services/analytics_service.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/movement/movement_program.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:video_player/video_player.dart';

/// Seans videosunu oynatan ekran (ADR-0004).
///
/// Oynatıcı bilerek sade: oynat/duraklat, ilerleme çubuğu, süre. Hareket
/// ederken kimse arayüzle uğraşmak istemez — kontroller azdır ve büyüktür.
class MovementPlayerScreen extends ConsumerStatefulWidget {
  const MovementPlayerScreen({
    super.key,
    required this.program,
    required this.session,
    this.createController,
  });

  final MovementProgram program;
  final MovementSession session;

  /// Testler için: gerçek platform oynatıcısı yerine sahte controller
  /// enjekte etmeyi sağlar. Üretimde hep null.
  @visibleForTesting
  final VideoPlayerController Function(String url)? createController;

  @override
  ConsumerState<MovementPlayerScreen> createState() =>
      _MovementPlayerScreenState();
}

enum _PlayerPhase { loading, ready, error }

/// Seans "tamamlandı" sayılacak kadar izlendi mi.
///
/// Son saniyeyi beklemek yerine %95: kapanış jeneriğinde ekrandan çıkan
/// kullanıcının ilerlemesi kaybolmasın. Süre bilinmiyorsa (0) karar verilemez.
@visibleForTesting
bool sessionWatchedEnough(Duration position, Duration duration) {
  final total = duration.inMilliseconds;
  if (total <= 0) return false;
  return position.inMilliseconds >= total * 0.95;
}

class _MovementPlayerScreenState extends ConsumerState<MovementPlayerScreen> {
  VideoPlayerController? _controller;
  _PlayerPhase _phase = _PlayerPhase.loading;

  /// Seans bir kez "tamamlandı" yazılır; video sonunda listener birkaç kez
  /// tetiklenebilir, tekrar tekrar Firestore'a yazmanın anlamı yok.
  bool _markedDone = false;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      // Controller oluşturma da try içinde: bozuk bir URL Uri.parse'ta ya da
      // platform katmanında patlarsa ekran hata durumuna düşsün, çökmesin.
      final controller =
          widget.createController?.call(widget.session.videoUrl) ??
          VideoPlayerController.networkUrl(Uri.parse(widget.session.videoUrl));
      _controller = controller;
      controller.addListener(_onTick);

      // Timeout olmadan bozuk/yavaş bir kaynak ekranı sonsuza dek
      // "yükleniyor"da bırakır (Sert Kural #4).
      await controller.initialize().timeout(const Duration(seconds: 30));
      if (!mounted) return;
      setState(() => _phase = _PlayerPhase.ready);
      unawaited(controller.play());
      unawaited(
        AnalyticsService.logEvent('movement_session_start', {
          'program_id': widget.program.id,
          'session_id': widget.session.id,
        }),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = _PlayerPhase.error);
    }
  }

  void _onTick() {
    final c = _controller;
    if (c == null || !mounted) return;
    final value = c.value;

    if (value.hasError && _phase != _PlayerPhase.error) {
      setState(() => _phase = _PlayerPhase.error);
      return;
    }
    if (_phase == _PlayerPhase.ready) setState(() {});

    if (!_markedDone && sessionWatchedEnough(value.position, value.duration)) {
      _markedDone = true;
      unawaited(_markDone());
    }
  }

  Future<void> _markDone() async {
    final repo = ref.read(movementProgressRepositoryProvider);
    unawaited(
      AnalyticsService.logEvent('movement_session_done', {
        'program_id': widget.program.id,
        'session_id': widget.session.id,
      }),
    );
    // Oturum yoksa (köprü hazır değil) ilerleme yazılamaz — kullanıcıya hata
    // göstermeyiz, video yine izlendi.
    await repo?.markSessionDone(widget.program.id, widget.session.id);
  }

  Future<void> _retry() async {
    setState(() => _phase = _PlayerPhase.loading);
    final old = _controller;
    _controller = null;
    old?.removeListener(_onTick);
    await old?.dispose();
    await _open();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);

    return Scaffold(
      // Video ekranı bilerek koyu: parlak bir arayüz videonun kendisiyle
      // yarışır. Bu, paletten bağımsız tek yüzey (sinema kuralı).
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _PlayerHeader(title: widget.session.title, l10n: l10n),
            Expanded(
              child: Center(
                child: switch (_phase) {
                  _PlayerPhase.loading => const CircularProgressIndicator(
                    color: Colors.white,
                  ),
                  _PlayerPhase.error => _PlayerError(
                    l10n: l10n,
                    p: p,
                    onRetry: _retry,
                  ),
                  _PlayerPhase.ready => _VideoSurface(
                    controller: _controller!,
                    l10n: l10n,
                    p: p,
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({required this.title, required this.l10n});

  final String title;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: l10n.a11yBack,
            child: Pressable(
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(fontSize: 14, color: Colors.white),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _VideoSurface extends StatelessWidget {
  const _VideoSurface({
    required this.controller,
    required this.l10n,
    required this.p,
  });

  final VideoPlayerController controller;
  final AppLocalizations l10n;
  final AppPalette p;

  static String _clock(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    final playing = value.isPlaying;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AspectRatio(
          aspectRatio: value.aspectRatio == 0 ? 16 / 9 : value.aspectRatio,
          child: VideoPlayer(controller),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: playing ? l10n.a11yMovementPause : l10n.a11yMovementPlay,
                child: Pressable(
                  onTap: () => playing ? controller.pause() : controller.play(),
                  child: Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: p.onAccent,
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: p.accent,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_clock(value.position)} / ${_clock(value.duration)}',
                style: AppTextStyles.body(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayerError extends StatelessWidget {
  const _PlayerError({
    required this.l10n,
    required this.p,
    required this.onRetry,
  });

  final AppLocalizations l10n;
  final AppPalette p;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.movementPlayerError,
          textAlign: TextAlign.center,
          style: AppTextStyles.body(fontSize: 14, color: Colors.white70),
        ),
        const SizedBox(height: 16),
        Pressable(
          onTap: onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: p.accent,
              borderRadius: BorderRadius.circular(AppSpacing.radius),
            ),
            child: Text(
              l10n.movementPlayerRetry,
              style: AppTextStyles.label(fontSize: 12, color: p.onAccent),
            ),
          ),
        ),
      ],
    );
  }
}
