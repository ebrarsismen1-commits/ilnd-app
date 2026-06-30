import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';

class AuthInputField extends ConsumerStatefulWidget {
  const AuthInputField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.trailing,
    this.hasError = false,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;
  final bool hasError;

  @override
  ConsumerState<AuthInputField> createState() => _AuthInputFieldState();
}

class _AuthInputFieldState extends ConsumerState<AuthInputField> {
  static const _danger = Color(0xFFB3554A);

  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focused != _focus.hasFocus) {
        setState(() => _focused = _focus.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(paletteProvider);
    final borderColor = widget.hasError
        ? _danger
        : _focused
        ? p.accent
        : Colors.transparent;
    final iconTextColor = widget.hasError
        ? _danger
        : _focused
        ? p.accent
        : p.textMuted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 52,
      decoration: BoxDecoration(
        color: p.surfaceStrong,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: (widget.hasError || _focused) ? 1.5 : 0,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(color: iconTextColor),
            child: Icon(widget.icon, size: 20, color: iconTextColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              onSubmitted: widget.onSubmitted,
              onChanged: widget.onChanged,
              style: AppTextStyles.body(fontSize: 15, color: p.text),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: AppTextStyles.display(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: p.textMuted,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (widget.trailing != null) ...[
            widget.trailing!,
            const SizedBox(width: 14),
          ],
        ],
      ),
    );
  }
}
