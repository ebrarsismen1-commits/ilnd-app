import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Önümüzdeki [days] gün için hatırlatma anlarını üretir.
///
/// Saf fonksiyon — plugin'e dokunmaz, testte doğrudan çağrılır.
/// [skipToday] true ise (kullanıcı bugün zaten aktifse) veya bugünün saati
/// geçmişse bugün atlanır; sonuç her zaman gelecekte kalan anlardır.
List<DateTime> computeReminderSlots({
  required DateTime now,
  required int hour,
  required int minute,
  required bool skipToday,
  int days = 7,
}) {
  final slots = <DateTime>[];
  for (var i = 0; slots.length < days && i <= days; i++) {
    final day = DateTime(now.year, now.month, now.day + i);
    final slot = DateTime(day.year, day.month, day.day, hour, minute);
    if (i == 0 && (skipToday || !slot.isAfter(now))) continue;
    slots.add(slot);
  }
  return slots;
}

/// Cihaz-yerel günlük hatırlatma bildirimi.
///
/// FCM değil: streak zaten cihazda hesaplanıyor, sunucu tarafı gerekmiyor
/// (mini-proposal: docs/decisions.md Faz 2 satırı). Web'de bildirim desteği
/// yok — tüm metodlar sessiz no-op.
///
/// Metin üretmez: başlık/gövde/kanal adı UI katmanından l10n ile gelir
/// (Sert Kural #1).
class ReminderService {
  ReminderService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const _channelId = 'daily_reminder';
  // 7 günlük pencere için sabit id aralığı — yeniden planlarken çakışmasın.
  static const _baseNotificationId = 4100;

  Future<void> _ensureInitialized() async {
    if (_initialized || kIsWeb) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name.identifier));
    } catch (_) {
      // Bilinmeyen bölge → tz.local varsayılanında kalır; bildirim yine
      // kurulur, en kötü durumda saat dilimi kayması olur.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  /// Bildirim izni ister; verilmediyse false döner.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await _ensureInitialized();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  /// Mevcut planı temizleyip [slots] için yeniden kurar.
  Future<void> scheduleDaily({
    required List<DateTime> slots,
    required String title,
    required String body,
    required String channelName,
  }) async {
    if (kIsWeb) return;
    await _ensureInitialized();
    await cancelAll();
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      await _plugin.zonedSchedule(
        id: _baseNotificationId + i,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.local(
          slot.year,
          slot.month,
          slot.day,
          slot.hour,
          slot.minute,
        ),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            channelName,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        // İnexact yeterli: dakikası dakikasına gerekmez, SCHEDULE_EXACT_ALARM
        // izni istememek Play incelemesini de sadeleştirir.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _ensureInitialized();
    await _plugin.cancelAll();
  }
}
