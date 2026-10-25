import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/app/theme/theme_settings.dart' show AppThemeScope;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/widgets/choice_dialog.dart' show showChoiceDialog;

/// The theme mode's localized name, shared by the dialog and the appearance
/// row that opens it.
String themeModeLabel(Translations t, DsThemeMode mode) => switch (mode) {
  DsThemeMode.system => t.settings.themeModeSystem,
  DsThemeMode.light => t.settings.themeModeLight,
  DsThemeMode.dark => t.settings.themeModeDark,
};

/// Opens the three-way theme choice in a dialog on touch shells. The radio
/// only stages a choice; confirming applies it through the root's theme
/// scope, cancelling leaves the theme as it was. A desktop title bar opens
/// a dropdown menu instead, and the appearance pane's row follows the same
/// platform rule through its own select.
Future<void> showThemeModeDialog(BuildContext context) async {
  final t = context.t;
  final current = AppThemeScope.of(context).settings.mode;
  final picked = await showChoiceDialog<DsThemeMode>(
    context: context,
    title: t.settings.themeMode,
    semanticLabel: t.settings.themeMode,
    value: current,
    options: [for (final mode in DsThemeMode.values) DsSelectOption(value: mode, label: themeModeLabel(t, mode))],
  );
  if (picked == null || picked == current || !context.mounted) return;
  final scope = AppThemeScope.of(context);
  final settings = scope.settings;
  if (picked != settings.mode) scope.onChanged(settings.rebuild((b) => b..mode = picked));
}
