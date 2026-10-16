import 'package:flutter/widgets.dart';
import 'package:live_shell/live_shell.dart' show CloseAction;
import 'package:live_uikit/live_uikit.dart';

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
Future<ClosePromptResult?> showClosePrompt(BuildContext context) {
  final draft = _ClosePromptDraft();
  return showLiveDialog<ClosePromptResult>(
    context: context,
    title: context.t.closePrompt.title,
    dismissible: false,
    child: _ClosePromptBody(draft: draft),
    actions: (dialogContext) => [
      LiveButton(
        label: dialogContext.t.common.cancel,
        variant: ButtonVariant.ghost,
        onPressed: () => Navigator.of(dialogContext).pop(),
      ),
      LiveButton(
        label: dialogContext.t.common.confirm,
        onPressed: () =>
            Navigator.of(dialogContext).pop(ClosePromptResult(action: draft.action, remember: draft.remember)),
      ),
    ],
  );
}

/// The answer the body has picked so far, read by the dialog's confirm button.
///
/// The actions are built by the caller of [showLiveDialog] and the choices live
/// in its child, so the two meet here rather than through a callback the child
/// would have to be handed.
final class _ClosePromptDraft {
  CloseAction action = CloseAction.hideToTray;
  bool remember = false;
}

class _ClosePromptBody extends StatefulWidget {
  const new({required this.draft});

  final _ClosePromptDraft draft;

  @override
  State<_ClosePromptBody> createState() => _ClosePromptBodyState();
}

class _ClosePromptBodyState extends State<_ClosePromptBody> {
  late CloseAction _action = widget.draft.action;
  late bool _remember = widget.draft.remember;

  @override
  Widget build(BuildContext context) {
    final t = context.t.closePrompt;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Two mutually exclusive answers, so the language's own choice control
        // rather than a radio group: the dispatched set has no radio, and a
        // segmented track says the same thing.
        LiveSegmented(
          labels: [t.toTray, t.quit],
          index: _action == CloseAction.hideToTray ? 0 : 1,
          onChanged: (index) => _choose(index == 0 ? CloseAction.hideToTray : CloseAction.quit),
        ),
        Padding(
          padding: EdgeInsets.only(top: LiveTheme.of(context).token.scale.sizes.md),
          child: LiveCheckbox(
            value: _remember,
            label: t.remember,
            onChanged: _rememberChoice,
          ),
        ),
      ],
    );
  }

  void _choose(CloseAction action) {
    setState(() => _action = action);
    widget.draft.action = action;
  }

  void _rememberChoice(bool remember) {
    setState(() => _remember = remember);
    widget.draft.remember = remember;
  }
}
