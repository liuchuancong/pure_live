import 'package:flutter/material.dart';
import 'package:live_shell/live_shell.dart' show CloseAction;

import 'package:pure_live/l10n/generated/strings.g.dart';

/// What the close prompt came back with.
final class ClosePromptResult {
  /// A result.
  const new({required this.action, required this.remember});

  /// The action the viewer picked.
  final CloseAction action;

  /// Whether this exact action should be applied without asking from now on.
  final bool remember;
}

/// Asks what closing the window should mean, the once-per-install question.
///
/// Shown the first time the window closes; the shell preferences store
/// persists the answer only when "remember" is checked, so an unchecked
/// answer costs one dialog per close but never silently rewrites the
/// viewer's habit.
Future<ClosePromptResult?> showClosePrompt(BuildContext context) => showDialog<ClosePromptResult>(
  context: context,
  barrierDismissible: false,
  builder: (context) => const _ClosePromptDialog(),
);

final class _ClosePromptDialog extends StatefulWidget {
  const new();

  @override
  State<_ClosePromptDialog> createState() => _ClosePromptDialogState();
}

final class _ClosePromptDialogState extends State<_ClosePromptDialog> {
  CloseAction _action = CloseAction.hideToTray;
  bool _remember = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t.closePrompt;
    return AlertDialog(
      title: Text(t.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioGroup<CloseAction>(
            groupValue: _action,
            onChanged: (value) => setState(() => _action = value ?? CloseAction.hideToTray),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<CloseAction>(value: CloseAction.hideToTray, title: Text(t.toTray)),
                RadioListTile<CloseAction>(value: CloseAction.quit, title: Text(t.quit)),
              ],
            ),
          ),
          CheckboxListTile(
            value: _remember,
            onChanged: (value) => setState(() => _remember = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(t.remember),
            dense: true,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(ClosePromptResult(action: _action, remember: _remember)),
          child: Text(context.t.common.confirm),
        ),
      ],
    );
  }
}
