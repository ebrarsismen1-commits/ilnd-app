import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/billing/usage_meter.dart';
import 'package:ilnd_app/core/demo/demo_config.dart';
import 'package:ilnd_app/core/ilnd/ilnd_fallbacks.dart';
import 'package:ilnd_app/core/ilnd/ilnd_learner.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/ilnd/ilnd_service.dart';

/// Sohbetteki tek mesaj.
class ChatMessage {
  const ChatMessage({
    required this.fromUser,
    required this.text,
    this.pending = false,
  });

  final bool fromUser;
  final String text;

  /// ILND yanıtı beklenirken gösterilen "yazıyor" balonu.
  final bool pending;

  ChatMessage toResolved(String text) =>
      ChatMessage(fromUser: false, text: text);
}

class ChatState {
  const ChatState({
    this.messages = const [],
    this.sending = false,
    this.limitReached = false,
  });

  final List<ChatMessage> messages;
  final bool sending;

  /// Ücretsiz haftalık limit doldu — ekran paywall göstermeli (tek seferlik).
  final bool limitReached;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? sending,
    bool? limitReached,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        sending: sending ?? this.sending,
        limitReached: limitReached ?? this.limitReached,
      );
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((ref) => ChatNotifier(ref));

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(this._ref) : super(_initialState());

  static ChatState _initialState() {
    if (!kDemoMode) return const ChatState();
    return ChatState(
      messages: [
        for (final m in kDemoChatOpening)
          ChatMessage(fromUser: m.fromUser, text: m.text),
      ],
    );
  }

  final Ref _ref;

  /// Geçmişi prompt'a verirken kaç tur taşıyacağımız (maliyet sınırı).
  static const _historyWindow = 8;

  /// Kaç kullanıcı mesajında bir hafıza çıkarımı yapılacağı (maliyet sınırı).
  static const _learnEvery = 4;
  int _userMessageCount = 0;

  /// Ekran paywall'ı gösterdikten sonra bayrağı temizler.
  void acknowledgeLimit() {
    if (state.limitReached) state = state.copyWith(limitReached: false);
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) return;

    // Ücretsiz katman limiti — dolduysa paywall'ı tetikle, mesajı gönderme.
    final gate = _ref.read(usageGateProvider);
    if (!gate.isAllowed(UsageKind.message)) {
      state = state.copyWith(limitReached: true);
      return;
    }

    final userMsg = ChatMessage(fromUser: true, text: trimmed);
    state = state.copyWith(
      messages: [...state.messages, userMsg, const ChatMessage(fromUser: false, text: '', pending: true)],
      sending: true,
    );

    final memory = _ref.read(ilndMemoryProvider);
    final service = _ref.read(ilndServiceProvider);

    // Pending balonu hariç son N turu bağlam olarak gönder.
    final history = state.messages
        .where((m) => !m.pending)
        .map((m) => IlndTurn(fromUser: m.fromUser, text: m.text))
        .toList();
    final windowed = history.length > _historyWindow
        ? history.sublist(history.length - _historyWindow)
        : history;
    // Son kullanıcı mesajını userMessage olarak ayır.
    final priorTurns =
        windowed.isNotEmpty ? windowed.sublist(0, windowed.length - 1) : <IlndTurn>[];

    String reply;
    try {
      reply = await service.respond(
        memory: memory,
        userMessage: trimmed,
        history: priorTurns,
        fallback: IlndFallbacks.chat(),
      );
    } catch (e) {
      reply = IlndService.friendlyError(e);
    }

    final resolved = [...state.messages];
    final pendingIdx = resolved.lastIndexWhere((m) => m.pending);
    if (pendingIdx != -1) {
      resolved[pendingIdx] = ChatMessage(fromUser: false, text: reply);
    }
    state = state.copyWith(messages: resolved, sending: false);

    // Kullanımı say (premium'da sayılmaz).
    await gate.record(UsageKind.message);

    // Hafızaya kısa bir iz bırak (ILND'nin "hatırlaması" için).
    await _ref.read(ilndMemoryProvider.notifier).addNote('Kullanıcı: $trimmed');

    // Birkaç mesajda bir kalıcı hafıza çıkar (fire-and-forget, maliyet sınırı).
    _userMessageCount++;
    if (_userMessageCount % _learnEvery == 0) {
      unawaited(_ref.read(ilndLearnerProvider).learnFrom(trimmed));
    }
  }
}
