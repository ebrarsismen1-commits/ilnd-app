import 'package:flutter/material.dart';
import 'package:ilnd_app/features/adan/island_name_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

class IslandNameDialog extends StatefulWidget {
  const IslandNameDialog({
    super.key,
    required this.initialName,
    required this.save,
  });
  final String? initialName;
  final Future<void> Function(String) save;

  @override
  State<IslandNameDialog> createState() => _IslandNameDialogState();
}

class _IslandNameDialogState extends State<IslandNameDialog> {
  late final _controller = TextEditingController(
    text: widget.initialName ?? '',
  );
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  bool _failed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.save(normalizeIslandName(_controller.text));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        title: Text(l.adanNameTitle),
        content: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _controller,
                autofocus: true,
                enabled: !_saving,
                maxLength: islandNameMaxLength,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l.adanNameLabel,
                  hintText: l.adanNameHint,
                ),
                validator: (value) =>
                    isValidIslandName(value ?? '') ? null : l.adanNameInvalid,
                onFieldSubmitted: (_) => _save(),
              ),
              if (_failed)
                Text(
                  l.preferencesSaveFailed,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(l.cancelAction),
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? l.stateLoading : l.preferencesSave),
          ),
        ],
      ),
    );
  }
}
