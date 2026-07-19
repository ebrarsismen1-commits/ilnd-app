import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/features/chat/chat_provider.dart';
import 'package:ilnd_app/features/chat/chat_screen.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/vibe_card/quote_card_widget.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Faz 3b — "ILND bana ne dedi" formatı: ILND'nin cümlesi tek dokunuşla
/// 9:16 karta döner; kartta alıntı + davet kodu rozeti yaşar.
class _StubChatNotifier extends ChatNotifier {
  _StubChatNotifier(super.ref, this._seed);
  final List<ChatMessage> _seed;

  @override
  Future<void> greetIfNeeded(AppLocalizations l10n) async {
    state = state.copyWith(messages: _seed);
  }
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  final l10n = lookupAppLocalizations(const Locale('tr'));

  group('QuoteCardWidget', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      required String quote,
      String code = '',
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: QuoteCardWidget(
              quote: quote,
              userName: 'Zeynep',
              p: AppPalette.light,
              referralCode: code,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('alıntı tırnak içinde, kod rozeti basılı', (tester) async {
      await pumpCard(
        tester,
        quote: 'Bugün kimseye açıklama borcun yok.',
        code: 'ABC123',
      );

      expect(find.text('“Bugün kimseye açıklama borcun yok.”'), findsOneWidget);
      expect(find.text(l10n.vibeCardInviteCode('ABC123')), findsOneWidget);
    });

    testWidgets('çok uzun alıntı kırpılır, kart taşmaz', (tester) async {
      await pumpCard(tester, quote: 'çok uzun bir cümle ' * 40);

      // Kırpma karakter sınırında: tam metin yok, "…" ile biten hâli var.
      final text = tester.widget<Text>(find.textContaining('…')).data!;
      expect(text.length, lessThanOrEqualTo(QuoteCardWidget.maxQuoteChars + 4));
    });
  });

  testWidgets('ILND mesajının altında "karta çevir" dokunuşu kartı açar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final router = GoRouter(
      initialLocation: routeChat,
      routes: [
        GoRoute(path: routeChat, builder: (_, _) => const ChatScreen()),
        GoRoute(
          path: routeQuoteCard,
          builder: (_, state) =>
              Scaffold(body: Text('STUB_CARD:${state.extra}')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ilndMemoryProvider.overrideWith(
            (ref) => IlndMemoryNotifier(prefs, '', null),
          ),
          chatProvider.overrideWith(
            (ref) => _StubChatNotifier(ref, const [
              ChatMessage(fromUser: false, text: 'küçük bir an yeter'),
              ChatMessage(fromUser: true, text: 'sağ ol'),
            ]),
          ),
        ],
        child: MaterialApp.router(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Dokunuş yalnız ILND mesajında — kullanıcı balonunda yok.
    expect(find.text(l10n.chatQuoteCardButton), findsOneWidget);

    await tester.tap(find.text(l10n.chatQuoteCardButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('STUB_CARD:küçük bir an yeter'), findsOneWidget);
  });
}
