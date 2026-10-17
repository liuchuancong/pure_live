import 'package:flutter/widgets.dart';

/// A settings page that a [SettingsTile.navigation] opens.
///
/// Give it to the tile's `destination`. In a [SettingsList], tapping the tile
/// pushes the page with the platform's page transition. In the list pane of a
/// [SettingsSplitView], it shows the page in the detail pane (or pushes it
/// when there is room for one pane only).
///
/// The package draws the page header (title, back button, [actions]) in the
/// tile's style; [builder] returns only the body, usually a [SettingsList].
/// A [SettingsList] in the body looks like the list that opened it: it
/// inherits the platform, brightness, themes and application type it
/// doesn't set itself.
///
/// ```dart
/// SettingsTile.navigation(
///   leading: const Icon(Icons.wifi),
///   title: const Text('Network & internet'),
///   destination: SettingsDestination(
///     id: 'network',
///     builder: (context) => SettingsList(sections: [...]),
///   ),
/// )
/// ```
@immutable
class SettingsDestination {
  const SettingsDestination({
    required this.id,
    this.title,
    required this.builder,
    this.actions,
  });

  /// Identifies the page, e.g. for [SettingsSplitController.select],
  /// [SettingsSplitView.initialDestinationId],
  /// [SettingsSplitView.onDestinationChanged] and state restoration.
  ///
  /// Must be unique among the destinations of a [SettingsSplitView]'s
  /// sections. Pushed pages also use it as their route name.
  final String id;

  /// The title in the page header. Defaults to the tile's title.
  final Widget? title;

  /// Builds the page body, below the header.
  final WidgetBuilder builder;

  /// Widgets at the end of the page header, such as icon buttons.
  final List<Widget>? actions;
}
