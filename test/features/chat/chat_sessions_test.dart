import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/billing/entitlement.dart';
import 'package:ilnd_app/core/billing/usage_meter.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/ilnd/ilnd_service.dart';
import 'package:ilnd_app/features/chat/chat_provider.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sohbet tek bir sonsuz akıştı ve eski bir konuşmaya dönmenin yolu yoktu
/// (owner, 2026-09-02: "sekme sekme olmamış"). Konuşmalar artık ayrı ayrı
/// duruyor. Üç sözleşme burada kilitleniyor: konuşmalar birbirine
/// KARIŞMAZ, eski tek akış kaybolmadan göç eder, silinen sohbet ILND'nin
/// hafızasını götürmez.
class _FakeIlndService extends IlndService {
  const _FakeIlndService();

  @override
  Future<String> respond({
    required IlndMemory memory,
    required String userMessage,
    required AppLocalizations l10n,
    List<IlndTurn> history = const [],
    String? task,
    IlndTier tier = IlndTier.quick,
    String? fallback,
    UsageKind? meterAs,
  }) async => 'tamam';

  @override
  Stream<String> respondStream({
    required IlndMemory memory,
    required String userMessage,
    required AppLocalizations l10n,
    List<IlndTurn> history = const [],
    String? task,
    IlndTier tier = IlndTier.quick,
    String? fallback,
    UsageKind? meterAs,
  }) async* {
    yield 'tamam';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = lookupAppLocalizations(const Locale('tr'));

  ProviderContainer containerFor(SharedPreferences prefs, {String? uid}) {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        hasPremiumAccessProvider.overrideWithValue(true),
        ilndMemoryProvider.overrideWith(
          (ref) => IlndMemoryNotifier(prefs, '', uid),
        ),
        ilndServiceProvider.overrideWithValue(const _FakeIlndService()),
        chatProvider.overrideWith(
          (ref) => ChatNotifier(ref, prefs: prefs, uid: uid),
        ),
      ],
    );
  }

  test('yeni sohbet temiz sayfa açar, eskisi listede kalır', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = containerFor(prefs, uid: 'user-1');
    final chat = container.read(chatProvider.notifier);

    await chat.send('uykum düzensiz', l10n);
    await chat.newSession();

    expect(
      container.read(chatProvider).messages,
      isEmpty,
      reason: 'Yeni sohbet boş açılır',
    );
    expect(container.read(chatProvider).sessions, hasLength(1));
    expect(container.read(chatProvider).sessions.first.title, 'uykum düzensiz');

    await chat.send('bugün yürüyüşe çıktım', l10n);
    final sessions = container.read(chatProvider).sessions;
    expect(sessions, hasLength(2), reason: 'İki ayrı konuşma');
    expect(
      sessions.first.title,
      'bugün yürüyüşe çıktım',
      reason: 'En son dokunulan en üstte',
    );
    container.dispose();
  });

  test('boş sohbette yeni sohbet demek boş kayıt üretmez', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = containerFor(prefs, uid: 'user-1');

    await container.read(chatProvider.notifier).newSession();
    await container.read(chatProvider.notifier).newSession();

    expect(container.read(chatProvider).sessions, isEmpty);
    container.dispose();
  });

  test('eski sohbete dönülür, mesajlar karışmaz', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = containerFor(prefs, uid: 'user-1');
    final chat = container.read(chatProvider.notifier);

    await chat.send('birinci konu', l10n);
    final firstId = container.read(chatProvider).activeId;
    await chat.newSession();
    await chat.send('ikinci konu', l10n);

    await chat.openSession(firstId);
    final messages = container.read(chatProvider).messages;
    expect(container.read(chatProvider).activeId, firstId);
    expect(messages.first.text, 'birinci konu');
    expect(
      messages.any((m) => m.text == 'ikinci konu'),
      isFalse,
      reason: 'İki konuşma birbirine karışmamalı',
    );
    container.dispose();
  });

  test('sohbetler yeniden açılışta listede durur', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final first = containerFor(prefs, uid: 'user-1');
    await first.read(chatProvider.notifier).send('birinci konu', l10n);
    await first.read(chatProvider.notifier).newSession();
    await first.read(chatProvider.notifier).send('ikinci konu', l10n);
    first.dispose();

    // Uygulama yeniden açıldı.
    final second = containerFor(prefs, uid: 'user-1');
    final state = second.read(chatProvider);
    expect(state.sessions, hasLength(2));
    expect(
      state.messages.first.text,
      'ikinci konu',
      reason: 'En son konuşulan sohbet açık gelir',
    );
    second.dispose();
  });

  test('sohbet silinir, açıktaki silinince en yenisine geçilir', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = containerFor(prefs, uid: 'user-1');
    final chat = container.read(chatProvider.notifier);

    await chat.send('birinci konu', l10n);
    await chat.newSession();
    await chat.send('ikinci konu', l10n);

    final activeId = container.read(chatProvider).activeId;
    await chat.deleteSession(activeId);

    final state = container.read(chatProvider);
    expect(state.sessions, hasLength(1));
    expect(state.messages.first.text, 'birinci konu');
    expect(state.activeId, isNot(activeId));
    container.dispose();
  });

  test('tek akışlı eski kayıt tek sohbete göç eder', () async {
    SharedPreferences.setMockInitialValues({
      'chat_history_user-1': jsonEncode([
        {'fromUser': true, 'text': 'eski konuşma'},
        {'fromUser': false, 'text': 'seni dinliyorum'},
      ]),
    });
    final prefs = await SharedPreferences.getInstance();

    final container = containerFor(prefs, uid: 'user-1');
    final state = container.read(chatProvider);

    expect(state.sessions, hasLength(1));
    expect(state.messages, hasLength(2));
    expect(state.messages.first.text, 'eski konuşma');
    expect(
      prefs.getString('chat_history_user-1'),
      isNull,
      reason: 'Göçten sonra eski anahtar kalmaz',
    );
    container.dispose();
  });

  test('sohbetler hesaba aittir, başka uid onları görmez', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final mine = containerFor(prefs, uid: 'user-1');
    await mine.read(chatProvider.notifier).send('gizli bir şey', l10n);
    mine.dispose();

    final other = containerFor(prefs, uid: 'user-2');
    expect(other.read(chatProvider).sessions, isEmpty);
    expect(other.read(chatProvider).messages, isEmpty);
    other.dispose();
  });
}
