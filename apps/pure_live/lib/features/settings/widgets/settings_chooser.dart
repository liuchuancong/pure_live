import 'package:flutter/material.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The chooser dialog: the reference's radio-list interaction over the uikit's
/// rows — the current choice marked by its leading check. Pops with the picked
/// value, null when cancelled.
///
/// A settings page reaches it from a `SettingsTile.navigation` row: the kit
/// states that a choice with more options than fit a menu opens a dialog, and
/// every design language gets the same radio list because the rows are the
/// uikit's own.
Future<T?> showSettingsChooser<T>(
  BuildContext context, {
  required String title,
  required T current,
  required List<(T, String)> options,
  String? hint,
}) => showPureDialog<T>(
  context: context,
  title: title,
  // A Builder so a row's submit pops the dialog route, not the page under it —
  // the dialog builds on the root navigator.
  child: Builder(
    builder: (dialogContext) => ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hint != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(
                  hint,
                  style: PureTheme.of(context).text.caption.copyWith(color: PureTheme.of(context).colors.textSecondary),
                ),
              ),
            for (var i = 0; i < options.length; i++)
              PureListRow(
                title: options[i].$2,
                leading: Icon(
                  options[i].$1 == current ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: options[i].$1 == current ? PureTheme.of(context).colors.primary : null,
                ),
                selected: options[i].$1 == current,
                onTap: () => Navigator.of(dialogContext).pop(options[i].$1),
                divided: i < options.length - 1,
              ),
          ],
        ),
      ),
    ),
  ),
);
