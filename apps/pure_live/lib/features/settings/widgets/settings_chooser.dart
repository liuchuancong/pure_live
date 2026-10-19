import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/settings/widgets/settings_surface.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The settings chooser: the reference's radio-list interaction over the uikit's
/// rows — the current choice marked by its leading check. Pops with the picked
/// value, null when cancelled.
///
/// A settings page reaches it from a `SettingsTile.navigation` row: a choice with
/// more options than fit a menu opens a surface of its own, and
/// [showSettingsSurface] decides which one — a centred dialog in a desktop window,
/// a bottom sheet on a handheld. The list is the same widget either way, because
/// the rows are the uikit's own and no design language gets to redraw a radio list
/// differently from the one beside it.
Future<T?> showSettingsChooser<T>(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required T current,
  required List<(T, String)> options,
  String? hint,
}) => showSettingsSurface<T>(
  context,
  ref,
  title: title,
  body: (surfaceContext) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (hint != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Text(
            hint,
            style: PureTheme.of(surfaceContext).text.caption
                .copyWith(color: PureTheme.of(surfaceContext).colors.textSecondary),
          ),
        ),
      for (var i = 0; i < options.length; i++)
        PureListRow(
          title: options[i].$2,
          leading: Icon(
            options[i].$1 == current ? Icons.check_circle : Icons.radio_button_unchecked,
            color: options[i].$1 == current ? PureTheme.of(surfaceContext).colors.primary : null,
          ),
          selected: options[i].$1 == current,
          onTap: () => Navigator.of(surfaceContext).pop(options[i].$1),
          divided: i < options.length - 1,
        ),
    ],
  ),
);
