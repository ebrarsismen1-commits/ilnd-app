import 'package:flutter/material.dart';
import 'package:ilnd_app/core/theme/app_text_styles.dart';

enum _ToastType { success, error, info }

class IlndToast {
  static void success(BuildContext context, String message) =>
      _show(context, message, _ToastType.success);

  static void error(BuildContext context, String message) =>
      _show(context, message, _ToastType.error);

  static void info(BuildContext context, String message) =>
      _show(context, message, _ToastType.info);

  static void _show(BuildContext context, String message, _ToastType type) {
    final color = switch (type) {
      _ToastType.success => const Color(0xFF1F9D57),
      _ToastType.error => const Color(0xFFB3554A),
      _ToastType.info => const Color(0xFF111827),
    };
    final icon = switch (type) {
      _ToastType.success => Icons.check_circle_outline_rounded,
      _ToastType.error => Icons.error_outline_rounded,
      _ToastType.info => Icons.info_outline_rounded,
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: color,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          duration: const Duration(seconds: 3),
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
