import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/confirm_delete.dart';
import 'package:ilnd_app/core/widgets/ilnd_toast.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/chat/chat_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Kayıtlı sohbetlerin listesi.
///
/// Sohbet önce tek bir sonsuz akıştı ve eski bir konuşmaya dönmenin yolu
/// yoktu: yukarı kaydırmak. Konuşmalar artık ayrı ayrı duruyor, buradan
/// açılıyor ve yeni bir konuya temiz sayfayla başlanıyor.
Future<void> showChatSessionsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.charcoal.withValues(alpha: 0.45),
    isScrollControlled: true,
    builder: (_) => const _ChatSessionsSheet(),
  );
}

class _ChatSessionsSheet extends ConsumerWidget {
  const _ChatSessionsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final state = ref.watch(chatProvider);
    final notifier = ref.read(chatProvider.notifier);

    // Açık sohbet henüz boşsa listede yer almaz: kaydedilmemiş bir konuşma
    // geçmişte görünmemeli.
    final sessions = state.sessions
        .where((s) => s.messages.isNotEmpty)
        .toList();

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        decoration: BoxDecoration(
          color: p.base,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          12,
          AppSpacing.screenPadding,
          24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.chatSessionsTitle,
                    style: AppTextStyles.display(fontSize: 22, color: p.text),
                  ),
                ),
                Pressable(
                  onTap: () async {
                    await notifier.newSession();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: p.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: p.onAccent),
                        const SizedBox(width: 5),
                        Text(
                          l10n.chatSessionsNew,
                          style: AppTextStyles.label(
                            fontSize: 11.5,
                            color: p.onAccent,
                          ).copyWith(letterSpacing: 0),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            if (sessions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Text(
                  l10n.chatSessionsEmpty,
                  style: AppTextStyles.body(fontSize: 14, color: p.textMuted),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sessions.length,
                  separatorBuilder: (_, _) =>
                      Container(height: 0.5, color: p.border),
                  itemBuilder: (context, i) {
                    final session = sessions[i];
                    return _SessionRow(
                      session: session,
                      isActive: session.id == state.activeId,
                      onOpen: () async {
                        await notifier.openSession(session.id);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      onDelete: () => _confirmDelete(context, ref, session),
                      p: p,
                      l10n: l10n,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  ChatSession session,
) async {
  final l10n = AppLocalizations.of(context)!;
  final ok = await confirmDelete(
    context,
    title: l10n.chatSessionDeleteTitle,
    body: l10n.chatSessionDeleteBody,
  );
  if (!ok || !context.mounted) return;

  try {
    await ref.read(chatProvider.notifier).deleteSession(session.id);
    if (context.mounted) IlndToast.success(context, l10n.chatSessionDeleted);
  } catch (_) {
    if (context.mounted) {
      IlndToast.error(context, l10n.chatSessionDeleteFailed);
    }
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.session,
    required this.isActive,
    required this.onOpen,
    required this.onDelete,
    required this.p,
    required this.l10n,
  });

  final ChatSession session;
  final bool isActive;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final title = session.title.isEmpty
        ? l10n.chatSessionUntitled
        : session.title;

    return Pressable(
      onTap: onOpen,
      onLongPress: onDelete,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Açık olan sohbet noktayla işaretlenir: listede nerede
            // olduğunu bilmek, hangisine döneceğine karar vermeyi kolaylaştırır.
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(top: 6, right: 10),
              decoration: BoxDecoration(
                color: isActive ? p.accent : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(
                      fontSize: 14.5,
                      color: p.text,
                    ).copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _whenLabel(session.updatedAt, l10n),
                    style: AppTextStyles.label(
                      fontSize: 10.5,
                      color: p.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              button: true,
              label: l10n.chatSessionDeleteTitle,
              child: Pressable(
                onTap: onDelete,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: p.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "bugün", "dün", "5 gün önce". Gün farkı takvim günü üzerinden ölçülür:
/// gece 23:50 ile 00:10 arası bir saat değil, bir gündür.
String _whenLabel(DateTime at, AppLocalizations l10n) {
  final now = DateTime.now();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(at.year, at.month, at.day)).inDays;
  if (days <= 0) return l10n.chatSessionToday;
  if (days == 1) return l10n.chatSessionYesterday;
  return l10n.chatSessionDaysAgo(days);
}
