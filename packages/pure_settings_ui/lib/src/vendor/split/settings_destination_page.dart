import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pure_settings_ui/src/vendor/sections/platforms/fluent_settings_section.dart';
import 'package:pure_settings_ui/src/vendor/split/settings_destination.dart';
import 'package:pure_settings_ui/src/vendor/split/settings_page_header.dart';
import 'package:pure_settings_ui/src/vendor/split/settings_page_trail.dart';
import 'package:pure_settings_ui/src/vendor/split/split_scopes.dart';
import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_style.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';

/// A destination page: the package's header over the destination's body.
/// Internal.
class SettingsDestinationPage extends StatelessWidget {
  const SettingsDestinationPage({
    super.key,
    required this.destination,
    required this.title,
    required this.config,
    this.isDetailRoot = false,
    this.parents = const <SettingsPageTrailEntry>[],
  });

  final SettingsDestination destination;

  /// The header title: the destination's title or the tile's.
  final Widget title;

  /// The style of the list that opened the page, which the body inherits.
  final SettingsStyleConfig config;

  /// Whether the page is the root of a split view's detail pane. There it
  /// only gets a back button in one pane, and the button closes the page
  /// through the split view.
  final bool isDetailRoot;

  /// The pages this one was opened from, first one first (the Windows
  /// style shows them as a breadcrumb).
  final List<SettingsPageTrailEntry> parents;

  @override
  Widget build(BuildContext context) {
    final style = config.resolve(context);
    final route = ModalRoute.of(context);
    final VoidCallback? onBack;
    if (isDetailRoot) {
      final split = SettingsSplitScope.maybeOf(context);
      onBack = split == null || split.isSplit ? null : split.goBack;
    } else {
      onBack = route != null && route.impliesAppBarDismissal
          ? () => Navigator.maybePop(context)
          : null;
    }

    final family = settingsStyleFamily(style.platform);
    Widget body = SettingsPageTrail(
      entries: [
        ...parents,
        SettingsPageTrailEntry(title: title, route: route),
      ],
      child: Builder(builder: destination.builder),
    );
    if (family == SettingsStyleFamily.fluent) {
      body = FluentPageTitleAbove(child: body);
    }

    return SettingsStyleScope(
      config: style.resolvedConfig,
      inherit: true,
      child: SettingsTheme(
        themeData: style.themeData,
        platform: style.platform,
        child: Material(
          color: style.themeData.settingsListBackground,
          child: family == SettingsStyleFamily.material
              ? SettingsCollapsingTitleView(
                  title: title,
                  actions: destination.actions,
                  onBack: onBack,
                  body: body,
                )
              : settingsHeaderOverBody(
                  context,
                  header: SettingsPageBar(
                    platform: style.platform,
                    title: title,
                    actions: destination.actions,
                    onBack: onBack,
                    parents: parents,
                  ),
                  body: body,
                ),
        ),
      ),
    );
  }
}

/// The platform route for a destination page pushed from a tile:
/// [CupertinoPageRoute] for the styles whose pages slide in over the last
/// one (iOS, macOS, GNOME), [MaterialPageRoute] otherwise (so Android gets
/// the app's page transitions, predictive back included).
Route<void> settingsDestinationRoute({
  required SettingsDestination destination,
  required Widget title,
  required SettingsStyleConfig config,
  required DevicePlatform platform,
  List<SettingsPageTrailEntry> parents = const <SettingsPageTrailEntry>[],
}) {
  final settings = RouteSettings(name: destination.id);
  Widget build(BuildContext context) => SettingsDestinationPage(
    destination: destination,
    title: title,
    config: config,
    parents: parents,
  );
  if (settingsUsesCupertinoRoutes(settingsStyleFamily(platform))) {
    return CupertinoPageRoute<void>(builder: build, settings: settings);
  }
  return MaterialPageRoute<void>(builder: build, settings: settings);
}

/// Opens [destination] from a tile at [context]: selects it when the tile is
/// in a split view's list pane, otherwise pushes its page on the nearest
/// [Navigator] (inside a split view's detail pane, that's the detail pane's).
void openSettingsDestination(
  BuildContext context, {
  required SettingsDestination destination,
  required Widget tileTitle,
}) {
  // Called from a tap, not from a build: the scopes are read without
  // depending on them, like the page trail below.
  final listScope = context
      .getInheritedWidgetOfExactType<SettingsSplitListScope>();
  if (listScope != null) {
    listScope.onOpen(destination, tileTitle);
    return;
  }
  final platform = context
      .getInheritedWidgetOfExactType<SettingsTheme>()!
      .platform;
  final config =
      context.getInheritedWidgetOfExactType<SettingsStyleScope>()?.config ??
      SettingsStyleConfig(platform: platform);
  Navigator.of(context).push(
    settingsDestinationRoute(
      destination: destination,
      title: destination.title ?? tileTitle,
      config: config,
      platform: platform,
      parents: SettingsPageTrail.entriesOf(context),
    ),
  );
}
