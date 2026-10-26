import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_shell/live_shell.dart' show CloseAction, CloseChoice;

import 'package:pure_live/app/providers/providers.dart';
import 'package:pure_live/l10n/translations.dart';

/// The reference's close dialog: what closing the window does, and whether
/// the question should stop being asked.
///
/// [tray] is whether a hidden window has an icon to come back from; without
/// one the stay choice minimizes to the taskbar instead.
Future<CloseChoice?> showCloseWindowDialog(BuildContext context, {required bool tray}) =>
    showDsDialog<CloseChoice>(
      context: context,
      builder: (_) => _CloseWindowDialog(tray: tray),
    );

final class _CloseWindowDialog extends ConsumerStatefulWidget {
  const _CloseWindowDialog({required this.tray});

  final bool tray;

  @override
  ConsumerState<_CloseWindowDialog> createState() => _CloseWindowDialogState();
}

final class _CloseWindowDialogState extends ConsumerState<_CloseWindowDialog> {
  bool _remember = false;
  bool _answering = false;

  Future<void> _answer(CloseAction action) async {
    if (_answering) return;
    _answering = true;
    await ref
        .read(shellWindowSettingsProvider.notifier)
        .rememberCloseChoice(action: action, dontAskAgain: _remember);
    if (!mounted) return;
    Navigator.of(context).pop((action: action, remember: _remember));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final stay = widget.tray ? CloseAction.hideToTray : CloseAction.minimise;
    return DsDialog(
      title: Text(t.settings.closeWindowTitle),
      icon: const DsIcon(DsIcons.panelLeftClose),
      destructive: true,
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          Text(t.settings.closeWindowQuestion),
          DsCheckbox(
            value: _remember,
            onChanged: (value) => setState(() => _remember = value ?? false),
            label: Text(t.settings.closeDontAskAgain),
          ),
        ],
      ),
      style: const DsDialogStyle(width: 440),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => unawaited(_answer(stay)),
          child: Text(widget.tray ? t.settings.closeHideToTray : t.settings.closeMinimise),
        ),
        DsButton(
          variant: DsButtonVariant.danger,
          onPressed: () => unawaited(_answer(CloseAction.quit)),
          child: Text(t.settings.closeQuit),
        ),
      ],
    );
  }
}
