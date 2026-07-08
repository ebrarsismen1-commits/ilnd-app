import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/features/chat/chat_provider.dart';
import 'package:ilnd_app/features/chat/chat_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// send() çağrılarını kaydeden sahte notifier — ağ/auth'a dokunmaz.
class _RecordingChatNotifier extends ChatNotifier {
  _RecordingChatNotifier(super.ref);

  final sent = <String>[];

  @override
  Future<void> send(String text, AppLocalizations l10n) async {
    sent.add(text);
  }
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  late _RecordingChatNotifier chat;

  Future<void> pumpChat(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatProvider.overrideWith((ref) {
            chat = _RecordingChatNotifier(ref);
            return chat;
          }),
          ilndMemoryProvider.overrideWith(
            (ref) => IlndMemoryNotifier(prefs, '', null),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChatScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Enter mesajı gönderir (web/masaüstü klavye)', (tester) async {
    await pumpChat(tester);

    await tester.enterText(find.byType(TextField), 'merhaba');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(chat.sent, ['merhaba']);
  });

  testWidgets('Shift+Enter göndermez — yeni satır için alanda kalır', (
    tester,
  ) async {
    await pumpChat(tester);

    await tester.enterText(find.byType(TextField), 'merhaba');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(chat.sent, isEmpty);
  });
}
