import 'package:flutter/material.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Geri alınamaz bir silme için onay penceresi.
///
/// Kullanıcının kendi yazdığı içerik siliniyor ve geri alma yok; tek bir
/// yanlış dokunuşla kaybolmamalı. Hesap silme diyaloğuyla (profile_screen)
/// aynı desen, tek yerde toplanmış hâli.
///
/// `true` yalnız kullanıcı açıkça onayladığında döner; pencereyi kenara
/// dokunarak kapatmak vazgeçmek sayılır.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancelAction),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.deleteAction),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
