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

/// Sohbet yalnız bellekteydi: uygulama kapanınca konuşma gidiyordu ve ILND
/// her açılışta yeniden karşılıyordu. Geçmiş artık cihazda, kullanıcıya ait
/// anahtarda durur. İki sözleşme burada kilitleniyor: konuşma geri gelir ve
/// başka bir hesaba SIZMAZ.
class _FakeIlndService extends IlndService {
  const _FakeIlndService(this.reply, {this.chunks = const []});
  final String reply;

  /// Akan yanıt: her eleman o ana kadar birikmiş metindir.
  final List<String> chunks;

  /// Son çağrıda modele giden geçmiş: pencere testi buna bakar.
  static List<IlndTurn> lastHistory = const [];

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
  }) async => reply;

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
    lastHistory = history;
    if (chunks.isEmpty) {
      yield reply;
      return;
    }
    for (final chunk in chunks) {
      yield chunk;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = lookupAppLocalizations(const Locale('tr'));

  ProviderContainer containerFor(
    SharedPreferences prefs, {
    String? uid,
    String reply = 'anladım, yanındayım',
    List<String> chunks = const [],
  }) {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Kota kapısı auth/Supabase'e uzanıyor; sohbet geçmişi testi onunla
        // ilgilenmiyor, premium diyerek kapıyı aradan çıkarıyoruz.
        hasPremiumAccessProvider.overrideWithValue(true),
        ilndMemoryProvider.overrideWith(
          (ref) => IlndMemoryNotifier(prefs, '', uid),
        ),
        ilndServiceProvider.overrideWithValue(
          _FakeIlndService(reply, chunks: chunks),
        ),
        // Auth'a bağlı kurulumu atla: uid doğrudan verilir.
        chatProvider.overrideWith(
          (ref) => ChatNotifier(ref, prefs: prefs, uid: uid),
        ),
      ],
    );
  }

  test('konuşma diske yazılır ve sonraki açılışta geri gelir', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final first = containerFor(prefs, uid: 'user-1');
    await first.read(chatProvider.notifier).send('bugün yorgunum', l10n);
    expect(first.read(chatProvider).messages, hasLength(2));
    first.dispose();

    // Uygulama yeniden açıldı.
    final second = containerFor(prefs, uid: 'user-1');
    final restored = second.read(chatProvider).messages;
    expect(restored, hasLength(2));
    expect(restored.first.fromUser, isTrue);
    expect(restored.first.text, 'bugün yorgunum');
    expect(restored.last.text, 'anladım, yanındayım');
    expect(
      restored.every((m) => !m.pending),
      isTrue,
      reason: 'Bekleyen balon bir arayüz durumu, geçmişin parçası değil',
    );
    second.dispose();
  });

  test('geçmiş hesaba aittir, başka uid onu görmez', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final mine = containerFor(prefs, uid: 'user-1');
    await mine.read(chatProvider.notifier).send('gizli bir şey', l10n);
    mine.dispose();

    final other = containerFor(prefs, uid: 'user-2');
    expect(other.read(chatProvider).messages, isEmpty);
    other.dispose();
  });

  test('geçmiş varken ILND yeniden karşılamaz', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final first = containerFor(prefs, uid: 'user-1');
    await first.read(chatProvider.notifier).send('selam', l10n);
    first.dispose();

    final second = containerFor(prefs, uid: 'user-1');
    await second.read(chatProvider.notifier).greetIfNeeded(l10n);
    expect(
      second.read(chatProvider).messages,
      hasLength(2),
      reason: 'Kaldığı yerden devam eder, üstüne yeni karşılama binmez',
    );
    second.dispose();
  });

  test('clearHistory sohbeti ve diskteki kaydı siler', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = containerFor(prefs, uid: 'user-1');
    await container.read(chatProvider.notifier).send('sil beni', l10n);
    expect(prefs.getString('chat_sessions_user-1'), isNotNull);

    await container.read(chatProvider.notifier).clearHistory();
    expect(container.read(chatProvider).messages, isEmpty);
    expect(prefs.getString('chat_sessions_user-1'), isNull);
    container.dispose();
  });

  test('yanıt akarken balon dolar, bitince yerleşir', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = containerFor(
      prefs,
      uid: 'user-1',
      chunks: const ['bugün', 'bugün zor', 'bugün zor geçmiş'],
    );

    final seen = <String>[];
    container.listen<ChatState>(chatProvider, (_, next) {
      final last = next.messages.isEmpty ? null : next.messages.last;
      if (last != null && !last.fromUser && last.text.isNotEmpty) {
        seen.add('${last.text}|${last.pending}');
      }
    });

    await container.read(chatProvider.notifier).send('nasılsın', l10n);

    expect(
      seen,
      containsAllInOrder([
        'bugün|true',
        'bugün zor|true',
        'bugün zor geçmiş|true',
      ]),
      reason: 'Kullanıcı cevabın bitmesini beklemeden metni görmeli',
    );
    // Akış bitince balon yerleşir: paylaşım kapısı ancak burada çıkar.
    final settled = container.read(chatProvider).messages.last;
    expect(settled.pending, isFalse);
    expect(settled.text, 'bugün zor geçmiş');
    container.dispose();
  });

  test('modele giden geçmiş dört turla ve kısa metinlerle sınırlı', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = containerFor(prefs, uid: 'user-1');
    final chat = container.read(chatProvider.notifier);

    // Uzun bir yapıştırma: pencereden çıkana kadar her mesajda fatura
    // ediyordu, artık kırpılarak gidiyor.
    await chat.send('x' * 1200, l10n);
    for (var i = 0; i < 6; i++) {
      await chat.send('mesaj $i', l10n);
    }

    final sent = _FakeIlndService.lastHistory;
    expect(
      sent.length,
      lessThanOrEqualTo(3),
      reason: 'Dört turluk pencerenin sonuncusu userMessage olarak ayrılır',
    );
    expect(
      sent.every((t) => t.text.length <= 403),
      isTrue,
      reason: 'Eski turlar kırpılır, uzun metin pencerede taşınmaz',
    );
    // Ekranda geçmişin tamamı durur: kısalan yalnız modele gidendir.
    expect(container.read(chatProvider).messages.length, 14);
    container.dispose();
  });

  test('bozuk kayıt sohbeti kırmaz, boş açar', () async {
    SharedPreferences.setMockInitialValues({
      'chat_history_user-1': 'bu json değil',
    });
    final prefs = await SharedPreferences.getInstance();

    final container = containerFor(prefs, uid: 'user-1');
    expect(container.read(chatProvider).messages, isEmpty);
    container.dispose();
  });
}
