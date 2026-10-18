import 'package:flutter/material.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// Marks a settings page that a `SettingsSplitView` detail pane owns: the
/// split view draws the page header (title, back button, breadcrumb) itself,
/// so the page under this marker shows only its body.
///
/// The marker is the app's own, not the package's scope: a settings page can
/// also be pushed as a full route (the typed routes in `app_router.dart`),
/// and only the destinations built for the split view are wrapped here.
class SettingsEmbedded extends InheritedWidget {
  /// Wraps [child] to say "a split view owns your header".
  const new({required super.child, super.key});

  /// Whether this [context] sits under a [SettingsEmbedded].
  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SettingsEmbedded>() != null;

  @override
  bool updateShouldNotify(SettingsEmbedded oldWidget) => false;
}

/// A settings page's chrome: the standalone scaffold with its title bar, or
/// nothing at all when the page is embedded in a `SettingsSplitView` detail
/// pane, which draws the header in the active design language itself.
///
/// Every section page builds through this so the same widget serves both
/// homes: the split view's pane (no bar, the pane's header carries the title
/// and the back button) and its own route above the shell (a
/// [PureScaffold] + [PureAppBar], as before).
class SettingsChrome extends StatelessWidget {
  /// The page [body], under a bar titled [title] when standalone.
  const new({
    required this.title,
    required this.body,
    this.actions = const <Widget>[],
    super.key,
  });

  /// The page title, for the standalone bar.
  final String title;

  /// The page content.
  final Widget body;

  /// Bar actions, for the standalone bar.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (SettingsEmbedded.of(context)) return body;
    return PureScaffold(
      appBar: PureAppBar(title: title, actions: actions),
      body: body,
    );
  }
}
