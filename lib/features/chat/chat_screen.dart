import 'package:flutter/material.dart';
import 'package:ilnd_app/core/widgets/motion.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/ilnd/crisis_guard.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/ilnd_surfaces.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/chat/chat_provider.dart';
import 'package:ilnd_app/features/chat/chat_sessions_sheet.dart';
import 'package:ilnd_app/features/premium/paywall_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Sohbet (Ada tasarımı 07): başlık, halka, üç konuşma önerisi, mesaj alanı.
///
/// Öneriler kullanıcı henüz bir şey yazmadıkça görünür. ILND sohbeti kendi
/// karşılamasıyla açtığı için "hiç mesaj yok" anı çoğu zaman bir kare
/// sürer; o yüzden öneriler karşılamanın ALTINDA da durur, yalnız boş
/// ekrana bağlı kalmaz.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.seedMessage});

  /// Verilirse sohbet bu mesajla açılır (ör. ilk-giriş ekranında seçilen
  /// "neye ihtiyacın var?" şıkkı) — ekran görünür görünmez otomatik gönderilir.
  final String? seedMessage;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final seed = widget.seedMessage?.trim();
    if (seed == null || seed.isEmpty) {
      // Seed yoksa sohbeti ILND açar: kişisel karşılama mesajı.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(chatProvider.notifier)
            .greetIfNeeded(AppLocalizations.of(context)!);
      });
    }
    if (seed != null && seed.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        ref.read(chatProvider.notifier).send(seed, l10n);
        _scrollToBottomSoon();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    _sendText(text);
  }

  void _sendText(String text) {
    final l10n = AppLocalizations.of(context)!;
    ref.read(chatProvider.notifier).send(text, l10n);
    // Mesaj gönderilmeye devam eder — destek dayatılmaz, sunulur.
    if (CrisisGuard.matches(text)) showCrisisResourceSheet(context);
    _scrollToBottomSoon();
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final state = ref.watch(chatProvider);
    final showSuggestions = !state.messages.any((m) => m.fromUser);

    ref.listen(chatProvider, (prev, next) {
      _scrollToBottomSoon();
      if (next.limitReached) {
        ref.read(chatProvider.notifier).acknowledgeLimit();
        PaywallScreen.show(
          context,
          reason: l10n.chatPaywallReason,
          source: 'chat',
        );
      }
    });

    return Scaffold(
      backgroundColor: p.base,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                8,
                AppSpacing.screenPadding - 4,
                4,
              ),
              child: IlndPageHeader(
                p: p,
                title: l10n.chatPageTitle,
                subtitle: l10n.chatListening,
                trailing: _SessionsGate(p: p, l10n: l10n),
              ),
            ),
            Expanded(
              child: state.messages.isEmpty
                  ? _Starter(p: p, l10n: l10n, onPick: _sendText)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenPadding,
                        16,
                        AppSpacing.screenPadding,
                        12,
                      ),
                      itemCount:
                          state.messages.length + (showSuggestions ? 1 : 0),
                      itemBuilder: (context, i) => i < state.messages.length
                          ? _Bubble(message: state.messages[i], p: p)
                          : Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: _Suggestions(
                                p: p,
                                l10n: l10n,
                                onPick: _sendText,
                              ),
                            ),
                    ),
            ),
            _Composer(
              controller: _controller,
              sending: state.sending,
              onSend: _send,
              p: p,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Kayıtlı sohbetler kapısı ─────────────────────────────────────────────────

/// Tek akışta eski bir konuşmaya dönmenin yolu yukarı kaydırmaktı; artık
/// listeden açılıyor.
///
/// İKON DEĞİL, ETİKET: release derlemesi ikon fontunu budadığı ve font uzun
/// süre önbellekte kaldığı için yeni eklenen bir glif kullanıcıda boş
/// çıkabiliyor (2026-09-02'de tam olarak bu oldu, bkz. firebase.json
/// /assets/** notu). Metin uygulamanın kendi yazı tipinden gelir.
class _SessionsGate extends StatelessWidget {
  const _SessionsGate({required this.p, required this.l10n});
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Pressable(
        onTap: () => showChatSessionsSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: p.border),
          ),
          child: Text(
            l10n.chatSessionsTitle,
            style: AppTextStyles.body(
              fontSize: 12,
              color: p.text,
            ).copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

// ─── Başlangıç: halka + soru + öneriler ──────────────────────────────────────

class _Starter extends StatelessWidget {
  const _Starter({required this.p, required this.l10n, required this.onPick});
  final AppPalette p;
  final AppLocalizations l10n;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: 16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ListeningRing(p: p),
              const SizedBox(height: 22),
              Text(
                l10n.chatEmptyTitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.pageTitle(color: p.text, fontSize: 25),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.chatEmptySubtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(fontSize: 14, color: p.textMuted),
              ),
              const SizedBox(height: 28),
              _Suggestions(p: p, l10n: l10n, onPick: onPick),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sohbet halkası: Su zemin, soluk hale, Orman çizgi. Nefes ritmiyle
/// büyüyüp küçülür; azaltılmış hareket modunda durur.
class _ListeningRing extends StatefulWidget {
  const _ListeningRing({required this.p});
  final AppPalette p;

  @override
  State<_ListeningRing> createState() => _ListeningRingState();
}

class _ListeningRingState extends State<_ListeningRing>
    with SingleTickerProviderStateMixin {
  // 4 sn al + 6 sn ver (DESIGN_SYSTEM §4 "nefes").
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.08,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.08,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 60,
    ),
  ]).animate(_c);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (prefersReducedMotion(context)) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return ExcludeSemantics(
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 114,
          height: 114,
          decoration: BoxDecoration(color: p.sea, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Container(
            width: 89,
            height: 89,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: p.accent.withValues(alpha: 0.28)),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: p.accent, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({
    required this.p,
    required this.l10n,
    required this.onPick,
  });
  final AppPalette p;
  final AppLocalizations l10n;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final text in [
          l10n.chatSuggestTired,
          l10n.chatSuggestSort,
          l10n.chatSuggestShare,
        ]) ...[
          Semantics(
            button: true,
            child: Pressable(
              onTap: () => onPick(text),
              scaleDown: 0.98,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                  border: Border.all(color: p.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        text,
                        style: AppTextStyles.body(
                          fontSize: 13.5,
                          color: p.text,
                          height: 1.3,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: p.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ─── Bubble ──────────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.p});
  final ChatMessage message;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    final isUser = message.fromUser;

    // ILND balonsuz + serif konuşur (editoryal ses); kullanıcı yeşil balonda —
    // "kim konuşuyor" hiyerarşisi renkten önce tipografiyle hissedilir.
    if (!isUser) {
      final l10n = AppLocalizations.of(context)!;
      return Padding(
        padding: const EdgeInsets.only(bottom: 14, right: 24),
        // Akarken metin zaten var: noktalar yalnız ilk kelime gelene kadar.
        child: message.pending && message.text.isEmpty
            ? _TypingDots(p: p)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: AppTextStyles.display(
                      fontSize: 16.5,
                      color: p.text,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // "ILND bana ne dedi" paylaşım kapısı: cümleyi karta çevir.
                  // Çok sessiz bir dokunuş — editoryal akışı bozmaz. Cümle
                  // akarken gizli: yarım cümle karta çevrilmemeli.
                  if (!message.pending)
                    Pressable(
                      onTap: () =>
                          context.push(routeQuoteCard, extra: message.text),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.crop_portrait_rounded,
                            size: 13,
                            color: p.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.chatQuoteCardButton,
                            style: AppTextStyles.label(
                              fontSize: 10,
                              color: p.textMuted,
                              letterSpacingEm: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: p.accent,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          message.text,
          style: AppTextStyles.body(
            fontSize: 15,
            height: 1.45,
            color: p.onAccent,
          ),
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots({required this.p});
  final AppPalette p;

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// Azaltılmış modda noktalar sabit durur: üç noktanın varlığı "yazıyor"u
  /// zaten anlatıyor, dalgalanma yalnız cila.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (prefersReducedMotion(context)) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 18,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (i) {
              final t = (_c.value - i * 0.2) % 1.0;
              final opacity = (0.3 + 0.7 * (1 - (t - 0.5).abs() * 2)).clamp(
                0.3,
                1.0,
              );
              return Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: widget.p.textMuted.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// ─── Composer ────────────────────────────────────────────────────────────────

/// Mesaj alanı: kenarlıklı kağıt kutu, gönder düğmesi kutunun İÇİNDE
/// (Ada tasarımı). Enter = gönder, Shift+Enter = yeni satır.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.p,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        6,
        AppSpacing.screenPadding,
        MediaQuery.viewInsetsOf(context).bottom > 0 ? 8 : 12,
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56, maxHeight: 140),
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          border: Border.all(color: p.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              // Çok satırlı TextField'da Enter varsayılan olarak yeni satır
              // ekler ve onSubmitted hiç tetiklenmez (web/masaüstü klavye).
              child: Focus(
                onKeyEvent: (node, event) {
                  final isEnter =
                      event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.numpadEnter;
                  if (!isEnter || HardwareKeyboard.instance.isShiftPressed) {
                    return KeyEventResult.ignored;
                  }
                  if (event is KeyDownEvent && !sending) onSend();
                  return KeyEventResult.handled;
                },
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTextStyles.body(fontSize: 15, color: p.text),
                  decoration: InputDecoration(
                    hintText: l10n.chatComposerHint,
                    hintStyle: AppTextStyles.body(
                      fontSize: 14.5,
                      color: p.textMuted,
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Semantics(
                button: true,
                label: l10n.chatSendA11y,
                child: Pressable(
                  onTap: sending ? null : onSend,
                  // Görsel çap 40, dokunma hedefi 44.
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: sending
                              ? p.accent.withValues(alpha: 0.5)
                              : p.accent,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: sending
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: p.onAccent,
                                ),
                              )
                            : Icon(
                                Icons.arrow_upward_rounded,
                                color: p.onAccent,
                                size: 20,
                              ),
                      ),
                    ),
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
