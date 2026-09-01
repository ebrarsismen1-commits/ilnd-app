import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/billing/usage_meter.dart';
import 'package:ilnd_app/core/ilnd/ilnd_service.dart';
import 'package:ilnd_app/features/chat/chat_provider.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ILND artık sohbeti kendisi açar: boş sohbete girildiğinde hafızadan
/// beslenen kişisel bir karşılama gelir; hata durumunda sıcak yedek mesaj.
class _FakeIlndService extends IlndService {
  _FakeIlndService({this.reply, this.throws = false});
  final String? reply;
  final bool throws;

  /// Son respond çağrısında gelen task — geri-referans garantisi doğrulanır.
  String? capturedTask;

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
  }) async {
    capturedTask = task;
    if (throws) {
      if (fallback != null) return fallback;
      throw const IlndServiceException('offline');
    }
    return reply!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = lookupAppLocalizations(const Locale('tr'));

  Future<ProviderContainer> makeContainer({
    required IlndService service,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ilndMemoryProvider.overrideWith(
          (ref) => IlndMemoryNotifier(prefs, '', null),
        ),
        ilndServiceProvider.overrideWithValue(service),
        // chatProvider'ın auth izleyen kurulumunu atla — test Supabase'siz.
        chatProvider.overrideWith((ref) => ChatNotifier(ref)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('boş sohbette ILND kişisel karşılamayla açar', () async {
    final container = await makeContainer(
      service: _FakeIlndService(reply: 'dün yorgundun, bu sabah nasıl?'),
    );
    final notifier = container.read(chatProvider.notifier);

    await notifier.greetIfNeeded(l10n);

    final messages = container.read(chatProvider).messages;
    expect(messages, hasLength(1));
    expect(messages.first.fromUser, isFalse);
    expect(messages.first.text, 'dün yorgundun, bu sabah nasıl?');
    expect(messages.first.pending, isFalse);
  });

  test('karşılama oturumda bir kez — ikinci çağrı mesaj eklemez', () async {
    final container = await makeContainer(
      service: _FakeIlndService(reply: 'selam sana'),
    );
    final notifier = container.read(chatProvider.notifier);

    await notifier.greetIfNeeded(l10n);
    await notifier.greetIfNeeded(l10n);

    expect(container.read(chatProvider).messages, hasLength(1));
  });

  test('hafızada not varsa karşılama görevi son notu zorunlu kılar', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = _FakeIlndService(reply: 'dün yorgundum demiştin — bugün?');
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ilndMemoryProvider.overrideWith(
          (ref) => IlndMemoryNotifier(prefs, '', null),
        ),
        ilndServiceProvider.overrideWithValue(service),
        chatProvider.overrideWith((ref) => ChatNotifier(ref)),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(ilndMemoryProvider.notifier)
        .addNote('Bugünkü ruh hali: yorgun');
    await container.read(chatProvider.notifier).greetIfNeeded(l10n);

    // Son not göreve birebir gömülür — geri-referans modele rica değil şarttır.
    expect(service.capturedTask, contains('Bugünkü ruh hali: yorgun'));
    expect(service.capturedTask, contains('mutlaka'));
    // Notun YAŞI da göreve girer. Girmediğinde model her notu bugüne ait
    // sanıyordu: iki hafta önceki erik için "bugün erikler nasıldı" diye
    // soruldu (2026-08-31).
    expect(
      service.capturedTask,
      contains('bugün'),
      reason: 'notun ne zaman alındığı göreve yazılmalı',
    );
  });

  test('bayat not karşılamada zorlanmaz', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = _FakeIlndService(reply: 'selam');
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ilndMemoryProvider.overrideWith(
          (ref) => IlndMemoryNotifier(prefs, '', null),
        ),
        ilndServiceProvider.overrideWithValue(service),
        chatProvider.overrideWith((ref) => ChatNotifier(ref)),
      ],
    );
    addTearDown(container.dispose);

    // İki hafta önceki bir öğün. Eskiden koşulsuz zorlanıyordu ve ILND
    // "bugün erikler nasıldı" diye soruyordu.
    final memory = container.read(ilndMemoryProvider.notifier);
    memory.state = memory.state.copyWith(
      recentNotes: [
        MemoryNote(
          'Yemek: Erik (120 kcal)',
          at: DateTime.now().subtract(const Duration(days: 14)),
        ),
      ],
    );

    await container.read(chatProvider.notifier).greetIfNeeded(l10n);

    expect(
      service.capturedTask,
      isNot(contains('Erik')),
      reason: 'iki haftalık öğün selamlamada gündeme getirilmemeli',
    );
    expect(service.capturedTask, isNot(contains('en son not')));
  });

  test('hafıza boşken karşılama görevi not referansı içermez', () async {
    final service = _FakeIlndService(reply: 'selam');
    final container = await makeContainer(service: service);

    await container.read(chatProvider.notifier).greetIfNeeded(l10n);

    expect(service.capturedTask, isNot(contains('en son not')));
  });

  test(
    'servis çökerse sıcak yedek karşılama gelir, hata balonu gelmez',
    () async {
      final container = await makeContainer(
        service: _FakeIlndService(throws: true),
      );
      final notifier = container.read(chatProvider.notifier);

      await notifier.greetIfNeeded(l10n);

      final messages = container.read(chatProvider).messages;
      expect(messages, hasLength(1));
      final greetings = [
        l10n.ilndFallbackGreeting1,
        l10n.ilndFallbackGreeting2,
        l10n.ilndFallbackGreeting3,
      ];
      expect(greetings, contains(messages.first.text));
    },
  );
}
