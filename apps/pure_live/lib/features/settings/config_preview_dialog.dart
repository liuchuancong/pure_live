import 'dart:convert' show JsonEncoder;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';

import 'package:pure_live/features/backup/backup_settings.dart' show captureSettingsSnapshot;
import 'package:pure_live/l10n/translations.dart';

/// Shows the backed-up settings as formatted JSON, with a copy action.
///
/// This is the app's version of the reference's local config preview: a
/// read-only view of the keys a backup carries, not an editor.
Future<void> showConfigPreview(BuildContext context) =>
    showDsDialog<void>(context: context, builder: (context) => const _ConfigPreviewDialog());

final class _ConfigPreviewDialog extends StatelessWidget {
  const _ConfigPreviewDialog();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final text = const JsonEncoder.withIndent('  ').convert(captureSettingsSnapshot());
    return DsDialog(
      title: Text(t.settings.configPreview),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          Text(t.settings.configPreviewDesc, style: theme.typography.small.copyWith(color: colors.textMuted)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: DecoratedBox(
              decoration: BoxDecoration(color: colors.control, borderRadius: BorderRadius.circular(theme.radii.card)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(DsSpace.s12),
                child: SelectableText(
                  text,
                  style: theme.typography.caption.copyWith(color: colors.text, fontFamily: 'monospace', height: 1.45),
                ),
              ),
            ),
          ),
        ],
      ),
      style: const DsDialogStyle(width: 640),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          leading: const DsIcon(DsIcons.copy),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (!context.mounted) return;
            showDsToast(context: context, title: t.settings.configPreviewCopied);
          },
          child: Text(t.settings.configPreviewCopy),
        ),
        DsButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.common.close)),
      ],
    );
  }
}
