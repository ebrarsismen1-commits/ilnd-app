import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/billing/usage_meter.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/core/demo/demo_config.dart';
import 'package:ilnd_app/core/ilnd/ilnd_fallbacks.dart';
import 'package:ilnd_app/core/ilnd/ilnd_learner.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/ilnd/ilnd_service.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Diske yazılan biçim. [pending] taşınmaz: bekleyen balon bir arayüz
  /// durumudur, geçmişin parçası değildir.
  Map<String, dynamic> toJson() => {'fromUser': fromUser, 'text': text};

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    fromUser: (j['fromUser'] as bool?) ?? false,
    text: (j['text'] as String?) ?? '',
  );
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
  }) => ChatState(
    messages: messages ?? this.messages,
    sending: sending ?? this.sending,
    limitReached: limitReached ?? this.limitReached,
  );
}

/// Sohbet geçmişinin SharedPreferences anahtarı. ILND hafızasıyla aynı
/// desen: kayıt kullanıcıya aittir, uid anahtara girer.
const _kChatHistory = 'chat_history';

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  // Hesap değişiminde sohbet sıfırlanır — önceki kullanıcının konuşması
  // ekranda ya da AI bağlamında yeni kullanıcıya taşınmaz. select(uid)
  // sayesinde token yenilemeleri (aynı uid) sohbeti sıfırlamaz.
  final uid = ref.watch(
    authNotifierProvider.select(
      (s) => s is AuthAuthenticated ? s.user.id : null,
    ),
  );
  return ChatNotifier(
    ref,
    prefs: ref.watch(sharedPreferencesProvider),
    uid: uid,
  );
});

/// Karşılamada geri-referans verilebilecek en eski not.
///
/// İki günden eskisine selamlamada değinmek "seni hatırlıyorum" değil
/// "takip mi ediyorsun" hissi veriyor. Hafızada kalmaya devam eder, yalnız
/// açılış cümlesinde zorlanmaz.
const int _greetingCallbackMaxAgeDays = 2;

class ChatNotifier extends StateNotifier<ChatState> {
  /// [prefs] verilmezse geçmiş yalnız bellekte tutulur; testler sohbeti
  /// diske dokunmadan kurabilsin diye opsiyonel.
  ChatNotifier(this._ref, {this._prefs, String? uid})
    : _key = uid == null ? _kChatHistory : '${_kChatHistory}_$uid',
      super(_initialState()) {
    _restore();
  }

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
  final SharedPreferences? _prefs;
  final String _key;

  /// Geçmişi prompt'a verirken kaç tur taşıyacağımız.
  ///
  /// Sekizden dörde indi (owner kararı 2026-09-02: "modelin eski
  /// konuşmaları çok iyi hatırlamasına gerek yok, kritik şeyleri tutsun
  /// yeter"). Uzun vadeli hatırlama zaten burada değil [IlndMemory]'de:
  /// hedefler, gerçekler ve tarihli notlar her çağrıda gidiyor. Bu pencere
  /// yalnız "şu an neyi konuşuyoruz" bağlamı.
  ///
  /// EKRANDAKİ geçmiş kısalmaz: kullanıcı bütün konuşmayı görmeye devam
  /// eder, kısalan yalnız modele gönderdiğimiz kısımdır.
  static const _historyWindow = 4;

  /// Modele giden eski turların karakter tavanı. Yapıştırılan uzun bir
  /// metin, pencereden çıkana kadar her mesajda yeniden fatura ediyordu.
  static const _historyTurnChars = 400;

  /// Diskte tutulan en fazla mesaj sayısı. Sohbet sınırsız büyürse
  /// SharedPreferences kaydı da büyür; ekranda gerçekten okunan pencere bu.
  static const _historyLimit = 50;

  /// Diskteki geçmişi yükler.
  ///
  /// Demo modunda dokunmaz: demo sohbeti sabit bir sahnedir, kullanıcının
  /// gerçek konuşmasıyla karışmamalı. Bozuk kayıt sessizce atılır, sohbet
  /// boş açılır: burada atılan bir hata ekranı komple kapatırdı.
  void _restore() {
    final prefs = _prefs;
    if (kDemoMode || prefs == null) return;
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final restored = [
        for (final entry in jsonDecode(raw) as List)
          ChatMessage.fromJson(Map<String, dynamic>.from(entry as Map)),
      ].where((m) => m.text.isNotEmpty).toList();
      if (restored.isNotEmpty) state = state.copyWith(messages: restored);
    } catch (_) {
      // bozuk veri — sohbet boş açılır
    }
  }

  Future<void> _persist() async {
    final prefs = _prefs;
    if (kDemoMode || prefs == null) return;
    final settled = state.messages.where((m) => !m.pending).toList();
    final windowed = settled.length > _historyLimit
        ? settled.sublist(settled.length - _historyLimit)
        : settled;
    await prefs.setString(
      _key,
      jsonEncode([for (final m in windowed) m.toJson()]),
    );
  }

  /// Sohbeti ve diskteki geçmişi siler. Kullanıcının konuşması cihazda
  /// kalıyorsa onu silmenin bir yolu da olmalı.
  Future<void> clearHistory() async {
    state = const ChatState();
    _greeted = false;
    await _prefs?.remove(_key);
  }

  /// Kaç kullanıcı mesajında bir hafıza çıkarımı yapılacağı (maliyet sınırı).
  static const _learnEvery = 4;
  int _userMessageCount = 0;

  /// Ekran paywall'ı gösterdikten sonra bayrağı temizler.
  void acknowledgeLimit() {
    if (state.limitReached) state = state.copyWith(limitReached: false);
  }

  bool _greeted = false;

  /// Sohbeti ILND açar: kullanıcı boş sohbete girdiğinde, hafızadaki son
  /// izlerden (mood, ritüel cevapları) beslenen kişisel tek bir karşılama
  /// mesajı gelir. "Seni tanıyan arkadaş" önce yazan taraftır. Oturumda bir
  /// kez ve yalnız boş sohbette çalışır; kota saymaz, hafızaya not düşmez.
  Future<void> greetIfNeeded(AppLocalizations l10n) async {
    if (kDemoMode) return;
    if (_greeted || state.sending || state.messages.isNotEmpty) return;
    _greeted = true;

    state = state.copyWith(
      messages: [const ChatMessage(fromUser: false, text: '', pending: true)],
      sending: true,
    );

    final memory = _ref.read(ilndMemoryProvider);
    final service = _ref.read(ilndServiceProvider);

    // Garantili geri-referans: "seni hatırlıyorum" anı şansa bırakılmaz.
    // Son not sistem bağlamında zaten var ama modelden ona değinmesini
    // AÇIKÇA istemezsek çoğu zaman genel bir selamla geçiştiriyor.
    //
    // AMA yalnız not TAZEYSE. Eskiden son not koşulsuz zorlanıyordu ve notun
    // yaşı da yazılmıyordu: iki hafta önce yenen bir erik için ILND
    // "bugün erikler nasıldı" diye soruyordu (2026-08-31'de yaşandı).
    // Geçen haftaki bir öğüne selamlamada değinmek sıcak değil, tuhaf.
    final now = DateTime.now();
    final fresh = memory.freshNotes(now);
    final lastNote = fresh.isNotEmpty ? fresh.last : null;
    final noteAge = lastNote?.ageInDays(now) ?? 0;
    final callback = (lastNote == null || noteAge > _greetingCallbackMaxAgeDays)
        ? ''
        : ' Hafızandaki en son not (${lastNote.whenLabel(now)}): '
              '"${lastNote.text}". Karşılamanda bu nota mutlaka doğal bir '
              'cümleyle değin — notun ZAMANINI doğru kullan (bugünse bugün, '
              'dünse dün de), birebir alıntılama, kendi sözlerinle '
              'hatırladığını göster.';

    String reply;
    try {
      reply = await service.respond(
        memory: memory,
        l10n: l10n,
        task:
            'Sohbeti SEN başlatıyorsun: kullanıcı ekranı yeni açtı ve henüz '
            'bir şey yazmadı.$callback',
        userMessage:
            'Beni kişisel tek bir mesajla karşıla. Hakkımda bildiklerini ve '
            'son notlarını (ruh hâli, gece ritüeli cevapları, hedefler) '
            'kullan; genel geçer bir selam verme. 1-2 kısa cümle, sonunda '
            'sohbeti açan sıcak bir soru olsun.',
        fallback: IlndFallbacks.greeting(l10n),
      );
    } catch (e) {
      reply = IlndFallbacks.greeting(l10n);
    }

    if (!mounted) return;
    final resolved = [...state.messages];
    final pendingIdx = resolved.lastIndexWhere((m) => m.pending);
    if (pendingIdx != -1) {
      resolved[pendingIdx] = ChatMessage(fromUser: false, text: reply);
    }
    state = state.copyWith(messages: resolved, sending: false);
    // Karşılama da geçmişin parçası: kaydedilmezse ILND her açılışta
    // yeniden karşılar ve kullanıcı dün konuştuklarını bulamaz.
    await _persist();
  }

  Future<void> send(String text, AppLocalizations l10n) async {
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
      messages: [
        ...state.messages,
        userMsg,
        const ChatMessage(fromUser: false, text: '', pending: true),
      ],
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
    // Son kullanıcı mesajını userMessage olarak ayır; ondan öncekiler
    // yalnız bağlam olduğu için kırpılarak gider.
    final priorTurns = windowed.isNotEmpty
        ? [
            for (final turn in windowed.sublist(0, windowed.length - 1))
              IlndTurn(
                fromUser: turn.fromUser,
                text: turn.text.length > _historyTurnChars
                    ? '${turn.text.substring(0, _historyTurnChars)}...'
                    : turn.text,
              ),
          ]
        : <IlndTurn>[];

    String reply = '';
    try {
      // Akan yanıt: her olayda birikmiş metnin tamamı gelir ve bekleyen
      // balon onunla dolar. Balon 'pending' kalır, çünkü cümle bitmeden
      // altındaki paylaşım kapısını göstermek yarım cümleyi kart yapmaya
      // davet ederdi.
      await for (final chunk in service.respondStream(
        memory: memory,
        userMessage: trimmed,
        history: priorTurns,
        fallback: IlndFallbacks.chat(l10n),
        l10n: l10n,
        meterAs: UsageKind.message,
      )) {
        reply = chunk;
        if (!mounted) return;
        final growing = [...state.messages];
        final growingIdx = growing.lastIndexWhere((m) => m.pending);
        if (growingIdx == -1) break;
        growing[growingIdx] = ChatMessage(
          fromUser: false,
          text: reply,
          pending: true,
        );
        state = state.copyWith(messages: growing);
      }
    } on IlndFreeLimitException {
      // Sunucu son sözü söyler: hak başka bir cihazda harcanmış olabilir,
      // yerel sayaç geride kalmış. Mesajı geri al, sayacı doluya çek ve
      // paywall'ı aç.
      if (!mounted) return;
      gate.markExhausted(UsageKind.message);
      final withoutAttempt = state.messages
          .where((m) => !m.pending && !identical(m, userMsg))
          .toList();
      state = state.copyWith(
        messages: withoutAttempt,
        sending: false,
        limitReached: true,
      );
      await _persist();
      return;
    } catch (e) {
      reply = IlndService.friendlyError(e, l10n);
    }

    // Hesap değişimi bu notifier'ı istek uçuştayken dispose etmiş olabilir.
    if (!mounted) return;

    final resolved = [...state.messages];
    final pendingIdx = resolved.lastIndexWhere((m) => m.pending);
    if (pendingIdx != -1) {
      resolved[pendingIdx] = ChatMessage(fromUser: false, text: reply);
    }
    state = state.copyWith(messages: resolved, sending: false);

    // Kullanımı say (premium'da sayılmaz). Gerçek sayaç sunucuda arttı;
    // bu, snapshot gelene kadar arayüzün doğru kalması için.
    gate.record(UsageKind.message);

    // Geçmiş diske yazılır: uygulama kapansa da konuşma kaldığı yerde durur.
    await _persist();

    // Hafızaya kısa bir iz bırak (ILND'nin "hatırlaması" için).
    await _ref.read(ilndMemoryProvider.notifier).addNote('Kullanıcı: $trimmed');

    // Birkaç mesajda bir kalıcı hafıza çıkar (fire-and-forget, maliyet sınırı).
    _userMessageCount++;
    if (_userMessageCount % _learnEvery == 0) {
      unawaited(_ref.read(ilndLearnerProvider).learnFrom(trimmed, l10n));
    }
  }
}
