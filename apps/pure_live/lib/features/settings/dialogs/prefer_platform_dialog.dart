import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/l10n/translations.dart';

/// The reference's preferred-platform picker: the platforms browsing shows,
/// a field that filters them by name or id, and an honest empty state when
/// nothing matches. Choosing a row applies it at once; Cancel answers null.
Future<String?> showPreferPlatformDialog({
  required BuildContext context,
  required List<DsSelectOption<String>> options,
  required String? value,
}) => showDsDialog<String>(
  context: context,
  builder: (context) => _PreferPlatformDialog(options: options, value: value),
);

final class _PreferPlatformDialog extends StatefulWidget {
  const _PreferPlatformDialog({required this.options, required this.value});

  final List<DsSelectOption<String>> options;
  final String? value;

  @override
  State<_PreferPlatformDialog> createState() => _PreferPlatformDialogState();
}

final class _PreferPlatformDialogState extends State<_PreferPlatformDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final query = _query.trim().toLowerCase();
    final matches = [
      for (final option in widget.options)
        if (query.isEmpty || option.label.toLowerCase().contains(query) || option.value.toLowerCase().contains(query))
          option,
    ];
    return DsDialog(
      title: Text(t.settings.preferPlatform),
      style: const DsDialogStyle(width: 420),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          DsSearchField(
            placeholder: t.settings.preferPlatformFilterHint,
            semanticLabel: t.settings.preferPlatformFilterHint,
            onChanged: (value) => setState(() => _query = value),
          ),
          if (matches.isEmpty)
            Padding(
              padding: const EdgeInsets.all(DsSpace.s16),
              child: Text(
                t.settings.preferPlatformFilterEmpty,
                textAlign: TextAlign.center,
                style: theme.typography.body.copyWith(color: colors.textMuted),
              ),
            )
          else
            DsListSection(
              children: [
                for (final option in matches)
                  DsListRow(
                    leading: option.leading,
                    title: Text(option.label),
                    description: option.detail == null ? null : Text(option.detail!),
                    selected: option.value == widget.value,
                    trailing: option.value == widget.value ? const DsIcon(DsIcons.check) : null,
                    onPressed: option.enabled ? () => Navigator.of(context).pop(option.value) : null,
                  ),
              ],
            ),
        ],
      ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
      ],
    );
  }
}
