import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/services/reminder_provider.dart';
import 'package:ilnd_app/core/services/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Plugin'e dokunmayan sahte servis: izin cevabı ve planlama çağrıları
/// gözlemlenebilir.
class _FakeReminderService extends ReminderService {
  _FakeReminderService({this.grant = true});

  final bool grant;
  int scheduleCalls = 0;
  List<DateTime> lastSlots = const [];
  bool cancelled = false;

  @override
  Future<bool> requestPermission() async => grant;

  @override
  Future<void> scheduleDaily({
    required List<DateTime> slots,
    required String title,
    required String body,
    required String channelName,
  }) async {
    scheduleCalls++;
    lastSlots = slots;
  }

  @override
  Future<void> cancelAll() async {
    cancelled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('computeReminderSlots', () {
    // 15 Temmuz 2026 12:00 — öğlen: 20:30 hatırlatması henüz geçmemiş.
    final noon = DateTime(2026, 7, 15, 12);

    test('bugünün saati geçmemişse bugünle başlar, 7 an üretir', () {
      final slots = computeReminderSlots(
        now: noon,
        hour: 20,
        minute: 30,
        skipToday: false,
      );
      expect(slots, hasLength(7));
      expect(slots.first, DateTime(2026, 7, 15, 20, 30));
      expect(slots.last, DateTime(2026, 7, 21, 20, 30));
    });

    test('bugün aktivite varsa bugün atlanır', () {
      final slots = computeReminderSlots(
        now: noon,
        hour: 20,
        minute: 30,
        skipToday: true,
      );
      expect(slots, hasLength(7));
      expect(slots.first, DateTime(2026, 7, 16, 20, 30));
    });

    test('bugünün saati geçtiyse bugün atlanır', () {
      final evening = DateTime(2026, 7, 15, 21);
      final slots = computeReminderSlots(
        now: evening,
        hour: 20,
        minute: 30,
        skipToday: false,
      );
      expect(slots.first, DateTime(2026, 7, 16, 20, 30));
    });

    test('tüm anlar gelecektedir', () {
      final slots = computeReminderSlots(
        now: DateTime(2026, 7, 15, 20, 30),
        hour: 20,
        minute: 30,
        skipToday: false,
      );
      expect(
        slots.every((s) => s.isAfter(DateTime(2026, 7, 15, 20, 30))),
        isTrue,
      );
    });
  });

  group('ReminderNotifier', () {
    Future<(ReminderNotifier, _FakeReminderService)> build({
      bool grant = true,
      Map<String, Object> prefsSeed = const {},
    }) async {
      SharedPreferences.setMockInitialValues(prefsSeed);
      final prefs = await SharedPreferences.getInstance();
      final service = _FakeReminderService(grant: grant);
      return (ReminderNotifier(prefs, service), service);
    }

    test('varsayılan: kapalı, 20:30', () async {
      final (notifier, _) = await build();
      expect(notifier.state.enabled, isFalse);
      expect(notifier.state.hour, 20);
      expect(notifier.state.minute, 30);
    });

    test('enable: izin verilirse açılır ve planlar', () async {
      final (notifier, service) = await build();
      final ok = await notifier.enable(
        title: 't',
        body: 'b',
        channelName: 'c',
        hasActivityToday: false,
      );
      expect(ok, isTrue);
      expect(notifier.state.enabled, isTrue);
      expect(service.scheduleCalls, 1);
      expect(service.lastSlots, isNotEmpty);
    });

    test('enable: izin reddedilirse kapalı kalır, planlamaz', () async {
      final (notifier, service) = await build(grant: false);
      final ok = await notifier.enable(
        title: 't',
        body: 'b',
        channelName: 'c',
        hasActivityToday: false,
      );
      expect(ok, isFalse);
      expect(notifier.state.enabled, isFalse);
      expect(service.scheduleCalls, 0);
    });

    test('disable: kapatır ve tüm bildirimleri iptal eder', () async {
      final (notifier, service) = await build(
        prefsSeed: {'reminder_enabled': true},
      );
      await notifier.disable();
      expect(notifier.state.enabled, isFalse);
      expect(service.cancelled, isTrue);
    });

    test('sync: kapalıyken hiçbir şey yapmaz', () async {
      final (notifier, service) = await build();
      await notifier.sync(
        title: 't',
        body: 'b',
        channelName: 'c',
        hasActivityToday: false,
      );
      expect(service.scheduleCalls, 0);
    });

    test('sync: açıkken planlar, aynı durum için ikinci çağrı no-op', () async {
      final (notifier, service) = await build(
        prefsSeed: {'reminder_enabled': true},
      );
      await notifier.sync(
        title: 't',
        body: 'b',
        channelName: 'c',
        hasActivityToday: false,
      );
      await notifier.sync(
        title: 't',
        body: 'b',
        channelName: 'c',
        hasActivityToday: false,
      );
      expect(service.scheduleCalls, 1);

      // Durum değişti (bugün aktivite yapıldı) → yeniden planlar.
      await notifier.sync(
        title: 't',
        body: 'b',
        channelName: 'c',
        hasActivityToday: true,
      );
      expect(service.scheduleCalls, 2);
    });
  });

  group('ReminderInviteDoneNotifier', () {
    test('varsayılan false, setDone kalıcı', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = ReminderInviteDoneNotifier(prefs);
      expect(notifier.state, isFalse);
      await notifier.setDone();
      expect(notifier.state, isTrue);
      expect(prefs.getBool('reminder_invite_done'), isTrue);
    });
  });
}
