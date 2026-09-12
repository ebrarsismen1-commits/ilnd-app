import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/services/reminder_provider.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/ilnd_surfaces.dart';
import 'package:ilnd_app/core/widgets/ilnd_toast.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Bildirim tercihleri (Ada tasarımı 20).
///
/// Bugün gerçekten ayarlanabilen iki şey var: günlük hatırlatmanın açık
/// olması ve saati. Tasarımdaki gün seçimi, sessiz saatler ve hassas
/// ayrıntıyı gizleme ReminderService'e girmeden anahtar olarak çizilmedi:
/// hiçbir şey değiştirmeyen bir anahtar sahte bir özelliktir.
///
/// Açılırken bildirim izni istenir; reddedilirse kapalı kalır ve kullanıcıya
/// cihaz ayarları yolu gösterilir. Metinler l10n'den (Kural #1).
class NotificationPrefsScreen extends ConsumerWidget {
  const NotificationPrefsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final settings = ref.watch(reminderProvider);
    final time = TimeOfDay(
      hour: settings.hour,
      minute: settings.minute,
    ).format(context);

    return Scaffold(
      backgroundColor: p.base,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            8,
            AppSpacing.screenPadding,
            32,
          ),
          children: [
            IlndPageHeader(
              p: p,
              title: l10n.notifTitle,
              subtitle: l10n.notifSubtitle,
            ),
            const SizedBox(height: 24),
            IlndCard(
              p: p,
              color: settings.enabled ? p.surfaceStrong : null,
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.reminderSettingLabel,
                          style: AppTextStyles.rowTitle(color: p.text),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l10n.reminderSettingSubtitle,
                          style: AppTextStyles.body(
                            fontSize: 12,
                            color: p.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: settings.enabled,
                    activeThumbColor: p.accent,
                    onChanged: (on) => _toggle(context, ref, on),
                  ),
                ],
              ),
            ),
            if (settings.enabled) ...[
              const SizedBox(height: 10),
              IlndListRow(
                p: p,
                icon: Icons.schedule_rounded,
                title: l10n.reminderTimeLabel(time),
                onTap: () => _pickTime(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool on) async {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(reminderProvider.notifier);
    if (!on) {
      await notifier.disable();
      return;
    }
    final granted = await notifier.enable(
      title: l10n.reminderNotificationTitle,
      body: l10n.reminderNotificationBody,
      channelName: l10n.reminderSettingLabel,
      hasActivityToday: ref.read(todaysMoodProvider) != null,
    );
    if (!granted && context.mounted) {
      IlndToast.info(context, l10n.reminderPermissionDenied);
    }
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.read(reminderProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.hour, minute: settings.minute),
    );
    if (picked == null || !context.mounted) return;
    await ref
        .read(reminderProvider.notifier)
        .setTime(
          hour: picked.hour,
          minute: picked.minute,
          title: l10n.reminderNotificationTitle,
          body: l10n.reminderNotificationBody,
          channelName: l10n.reminderSettingLabel,
          hasActivityToday: ref.read(todaysMoodProvider) != null,
        );
  }
}
