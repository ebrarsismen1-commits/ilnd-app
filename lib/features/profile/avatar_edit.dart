import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ilnd_app/core/repositories/avatar_repository.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/ilnd_toast.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Profil fotoğrafını gösterir: kayıtlı foto varsa onu, yoksa baş harfi
/// (accent daire). Profil başlığında ve ana sayfa hero'sunda ortak kullanılır.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    super.key,
    required this.size,
    required this.initial,
    required this.p,
    this.fontSize,
  });

  final double size;
  final String initial;
  final AppPalette p;
  final double? fontSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b64 = ref.watch(userAvatarProvider).valueOrNull;
    final image = _decode(b64);

    if (image != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(image: MemoryImage(image), fit: BoxFit.cover),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTextStyles.display(
          fontSize: fontSize ?? size * 0.42,
          color: p.onAccent,
        ),
      ),
    );
  }
}

Uint8List? _decode(String? b64) {
  if (b64 == null || b64.isEmpty) return null;
  try {
    return base64Decode(b64);
  } catch (_) {
    return null;
  }
}

/// Fotoğraf seçenekleri: galeriden seç / (varsa) kaldır.
Future<void> showAvatarOptions(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context)!;
  final p = ref.read(paletteProvider);
  final hasPhoto = ref.read(userAvatarProvider).valueOrNull != null;

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: p.base,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: p.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _AvatarOption(
              icon: Icons.photo_library_outlined,
              label: l10n.profilePhotoFromGallery,
              p: p,
              onTap: () {
                Navigator.of(sheetContext).pop();
                pickAndSaveAvatar(context, ref);
              },
            ),
            if (hasPhoto) ...[
              const SizedBox(height: 8),
              _AvatarOption(
                icon: Icons.delete_outline_rounded,
                label: l10n.profilePhotoRemove,
                p: p,
                danger: true,
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await ref.read(avatarRepositoryProvider)?.remove();
                },
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Galeriden fotoğraf seçer, 512px'e küçültür, base64'e çevirip kaydeder.
/// İptal sessizce döner; hata/aşırı büyük durumunda kullanıcıya toast gösterir.
Future<void> pickAndSaveAvatar(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final repo = ref.read(avatarRepositoryProvider);
  if (repo == null) return;

  try {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 70,
    );
    if (file == null) return; // iptal
    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);
    // Firestore doküman sınırı 1MB — base64 ~%33 şişer. 512px+kalite 70 ile
    // buranın çok altında kalınır; yine de güvenlik payı bırak.
    if (b64.length > 900000) {
      if (context.mounted) IlndToast.error(context, l10n.profilePhotoTooLarge);
      return;
    }
    await repo.save(b64);
    if (context.mounted) IlndToast.success(context, l10n.profilePhotoUpdated);
  } catch (e) {
    if (context.mounted) IlndToast.error(context, l10n.profilePhotoFailed);
  }
}

class _AvatarOption extends StatelessWidget {
  const _AvatarOption({
    required this.icon,
    required this.label,
    required this.p,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final AppPalette p;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFB3554A) : p.text;
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          border: Border.all(color: p.border, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTextStyles.body(
                fontSize: 15,
                color: color,
              ).copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
