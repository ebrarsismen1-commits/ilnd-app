import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/ilnd/ilnd_service.dart';
import 'package:ilnd_app/features/chat/chat_provider.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ILND artık sohbeti kendisi açar: boş sohbete girildiğinde hafızadan
/// beslenen kişisel bir karşılama gelir; hata durumunda sıcak yedek mesaj.
class _FakeIlndService extends IlndService {
  const _FakeIlndService({this.reply, this.throws = false});
  final String? reply;
  final bool throws;

  @override
  Future<String> respond({
    required IlndMemory memory,
    required String userMessage,
    required AppLocalizations l10n,
    List<IlndTurn> history = const [],
    String? task,
    IlndTier tier = IlndTier.quick,
    String? fallback,
  }) async {
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
      service: const _FakeIlndService(reply: 'dün yorgundun, bu sabah nasıl?'),
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
      service: const _FakeIlndService(reply: 'selam sana'),
    );
    final notifier = container.read(chatProvider.notifier);

    await notifier.greetIfNeeded(l10n);
    await notifier.greetIfNeeded(l10n);

    expect(container.read(chatProvider).messages, hasLength(1));
  });

  test(
    'servis çökerse sıcak yedek karşılama gelir, hata balonu gelmez',
    () async {
      final container = await makeContainer(
        service: const _FakeIlndService(throws: true),
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
