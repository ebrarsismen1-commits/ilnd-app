import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/ilnd/crisis_guard.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
import 'package:ilnd_app/core/widgets/breath_ring.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/chat/chat_provider.dart';
import 'package:ilnd_app/features/premium/paywall_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

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
    final name = ref.watch(ilndMemoryProvider).name;

    ref.listen(chatProvider, (prev, next) {
      _scrollToBottomSoon();
      if (next.limitReached) {
        ref.read(chatProvider.notifier).acknowledgeLimit();
        PaywallScreen.show(context, reason: l10n.chatPaywallReason);
      }
    });

    return Scaffold(
      backgroundColor: p.base,
      body: AnimatedBackground(
        palette: p,
        child: SafeArea(
          child: Column(
            children: [
              _Header(p: p, l10n: l10n),
              Expanded(
                child: state.messages.isEmpty
                    ? _EmptyState(name: name, p: p, l10n: l10n)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenPadding,
                          12,
                          AppSpacing.screenPadding,
                          12,
                        ),
                        itemCount: state.messages.length,
                        itemBuilder: (context, i) =>
                            _Bubble(message: state.messages[i], p: p),
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
      ),
    );
  }
}

// ─── Header — nefes halkası burada da yaşar (marka jesti tek yerde değil) ─────

class _Header extends StatelessWidget {
  const _Header({required this.p, required this.l10n});
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Pressable(
              onTap: () => Navigator.of(context).maybePop(),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 24,
                  color: p.textMuted,
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BreathRing(size: 40),
              const SizedBox(height: 6),
              Text(
                l10n.chatListening,
                style: AppTextStyles.body(fontSize: 10.5, color: p.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.name, required this.p, required this.l10n});
  final String name;
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final greeting = name.isNotEmpty
        ? l10n.chatGreetingWithName(name)
        : l10n.chatGreeting;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            greeting,
            style: AppTextStyles.display(fontSize: 30, color: p.text),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.chatEmptyPrompt,
            style: AppTextStyles.body(
              fontSize: 15,
              color: p.textMuted,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
      return Padding(
        padding: const EdgeInsets.only(bottom: 14, right: 24),
        child: message.pending
            ? _TypingDots(p: p)
            : Text(
                message.text,
                style: AppTextStyles.display(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: p.text,
                  height: 1.45,
                ),
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
  )..repeat();

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
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        8,
        AppSpacing.screenPadding,
        MediaQuery.viewInsetsOf(context).bottom > 0 ? 8 : 12,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.border, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 48, maxHeight: 120),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: p.border, width: 0.5),
              ),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                style: AppTextStyles.body(fontSize: 15, color: p.text),
                decoration: InputDecoration(
                  hintText: l10n.chatComposerHint,
                  hintStyle: AppTextStyles.body(
                    fontSize: 15,
                    color: p.textMuted,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Pressable(
            onTap: sending ? null : onSend,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: sending ? p.accent.withValues(alpha: 0.5) : p.accent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: sending
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: p.onAccent,
                      ),
                    )
                  : Icon(
                      Icons.arrow_upward_rounded,
                      color: p.onAccent,
                      size: 22,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
