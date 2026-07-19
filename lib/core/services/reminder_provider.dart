import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ilnd_app/core/services/analytics_service.dart';
import 'package:ilnd_app/core/services/reminder_service.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';

const _kEnabled = 'reminder_enabled';
const _kHour = 'reminder_hour';
const _kMinute = 'reminder_minute';
const _kInviteDone = 'reminder_invite_done';

/// Hatırlatma ayarı cihaz tercihi — kullanıcı verisi değil, o yüzden
/// SharedPreferences'ta ve uid-bağımsız (streak_tracker ile aynı gerekçe).
class ReminderSettings {
  const ReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final bool enabled;
  final int hour;
  final int minute;

  // Varsayılan kapalı (opt-in) — non-preachy: istemeyen kullanıcıya
  // tek bildirim bile gitmez. 20:30 = günün kapanışına nazik pencere.
  static const defaults = ReminderSettings(
    enabled: false,
    hour: 20,
    minute: 30,
  );

  ReminderSettings copyWith({bool? enabled, int? hour, int? minute}) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }
}

final reminderServiceProvider = Provider<ReminderService>(
  (ref) => ReminderService(),
);

/// Ana ekrandaki tek seferlik hatırlatma daveti cevaplandı mı?
/// Kabul de ret de kalıcıdır — kullanıcıya aynı soru ikinci kez sorulmaz
/// (non-preachy); fikir değiştirirse ayarlardaki toggle her zaman orada.
final reminderInviteDoneProvider =
    StateNotifierProvider<ReminderInviteDoneNotifier, bool>((ref) {
      return ReminderInviteDoneNotifier(ref.watch(sharedPreferencesProvider));
    });

class ReminderInviteDoneNotifier extends StateNotifier<bool> {
  ReminderInviteDoneNotifier(this._prefs)
    : super(_prefs.getBool(_kInviteDone) ?? false);

  final SharedPreferences _prefs;

  Future<void> setDone() async {
    state = true;
    await _prefs.setBool(_kInviteDone, true);
  }
}

final reminderProvider =
    StateNotifierProvider<ReminderNotifier, ReminderSettings>((ref) {
      return ReminderNotifier(
        ref.watch(sharedPreferencesProvider),
        ref.watch(reminderServiceProvider),
      );
    });

class ReminderNotifier extends StateNotifier<ReminderSettings> {
  ReminderNotifier(this._prefs, this._service)
    : super(
        ReminderSettings(
          enabled:
              _prefs.getBool(_kEnabled) ?? ReminderSettings.defaults.enabled,
          hour: _prefs.getInt(_kHour) ?? ReminderSettings.defaults.hour,
          minute: _prefs.getInt(_kMinute) ?? ReminderSettings.defaults.minute,
        ),
      );

  final SharedPreferences _prefs;
  final ReminderService _service;

  // Aynı oturum içinde gereksiz yeniden planlamayı önler (home her build'de
  // sync çağırır); gün/ayar/aktivite değişince anahtar değişir.
  String? _lastSyncKey;

  /// Kullanıcı toggle'ı açtı: izin iste, verildiyse kaydet + planla.
  /// İzin yoksa false döner, ayar kapalı kalır (UI toast gösterir).
  Future<bool> enable({
    required String title,
    required String body,
    required String channelName,
    required bool hasActivityToday,
  }) async {
    final granted = await _service.requestPermission();
    if (!mounted) return false;
    if (!granted) return false;
    state = state.copyWith(enabled: true);
    await _prefs.setBool(_kEnabled, true);
    unawaited(AnalyticsService.logEvent('reminder_enabled', {}));
    await _reschedule(
      title: title,
      body: body,
      channelName: channelName,
      hasActivityToday: hasActivityToday,
    );
    return true;
  }

  Future<void> disable() async {
    state = state.copyWith(enabled: false);
    await _prefs.setBool(_kEnabled, false);
    _lastSyncKey = null;
    unawaited(AnalyticsService.logEvent('reminder_disabled', {}));
    await _service.cancelAll();
  }

  Future<void> setTime({
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String channelName,
    required bool hasActivityToday,
  }) async {
    state = state.copyWith(hour: hour, minute: minute);
    await _prefs.setInt(_kHour, hour);
    await _prefs.setInt(_kMinute, minute);
    unawaited(
      AnalyticsService.logEvent('reminder_time_changed', {
        'hour': hour,
        'minute': minute,
      }),
    );
    if (state.enabled) {
      await _reschedule(
        title: title,
        body: body,
        channelName: channelName,
        hasActivityToday: hasActivityToday,
      );
    }
  }

  /// Uygulama açılışında çağrılır: pencereyi taze tutar (7 gün ileri kayar,
  /// bugün aktivite yapıldıysa bugünün bildirimi düşer). Oturum içinde
  /// aynı durum için tekrarlanan çağrılar no-op.
  Future<void> sync({
    required String title,
    required String body,
    required String channelName,
    required bool hasActivityToday,
  }) async {
    if (!state.enabled) return;
    final now = DateTime.now();
    final key =
        '${now.year}-${now.month}-${now.day}'
        '|${state.hour}:${state.minute}|$hasActivityToday';
    if (key == _lastSyncKey) return;
    _lastSyncKey = key;
    await _reschedule(
      title: title,
      body: body,
      channelName: channelName,
      hasActivityToday: hasActivityToday,
    );
  }

  Future<void> _reschedule({
    required String title,
    required String body,
    required String channelName,
    required bool hasActivityToday,
  }) async {
    final slots = computeReminderSlots(
      now: DateTime.now(),
      hour: state.hour,
      minute: state.minute,
      skipToday: hasActivityToday,
    );
    await _service.scheduleDaily(
      slots: slots,
      title: title,
      body: body,
      channelName: channelName,
    );
  }
}
