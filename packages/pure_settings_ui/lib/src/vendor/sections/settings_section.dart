import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_section.dart';
import 'package:pure_settings_ui/src/vendor/sections/abstract_settings_section.dart';
import 'package:pure_settings_ui/src/vendor/sections/platforms/adwaita_settings_section.dart';
import 'package:pure_settings_ui/src/vendor/sections/platforms/android_settings_section.dart';
import 'package:pure_settings_ui/src/vendor/sections/platforms/fluent_settings_section.dart';
import 'package:pure_settings_ui/src/vendor/sections/platforms/ios_settings_section.dart';
import 'package:pure_settings_ui/src/vendor/sections/platforms/macos_settings_section.dart';
import 'package:pure_settings_ui/src/vendor/sections/platforms/web_settings_section.dart';
import 'package:pure_settings_ui/src/vendor/split/adwaita_split.dart';
import 'package:pure_settings_ui/src/vendor/split/fluent_split.dart';
import 'package:pure_settings_ui/src/vendor/split/macos_split.dart';
import 'package:pure_settings_ui/src/vendor/split/split_scopes.dart';
import 'package:pure_settings_ui/src/vendor/tiles/abstract_settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';
import 'package:pure_settings_ui/src/vendor/utils/unresolved_platform.dart';

/// A group of tiles with an optional [title].
///
/// Each style draws it its own way: one card (iOS, macOS, web, GNOME), or a
/// card per tile (Android, Windows). A section with no [tiles] renders
/// nothing, so tiles can be added with collection `if`.
class SettingsSection extends AbstractSettingsSection {
  /// Creates a section of [tiles].
  const SettingsSection({
    required this.tiles,
    this.margin,
    this.title,
    this.titlePadding,
    super.key,
  });

  /// The tiles, top to bottom: `SettingsTile`s, `CustomSettingsTile`s or your
  /// own [AbstractSettingsTile]s.
  final List<AbstractSettingsTile> tiles;

  /// Replaces the section's default outer margin.
  final EdgeInsetsDirectional? margin;

  /// The section header, usually a [Text] in sentence case.
  final Widget? title;

  /// Replaces the default padding around [title].
  final EdgeInsetsGeometry? titlePadding;

  @override
  Widget build(BuildContext context) {
    // A section with no tiles (e.g. all of them are conditional) shows
    // nothing, not a header over an empty card.
    if (tiles.isEmpty) return const SizedBox.shrink();

    final theme = SettingsTheme.of(context);

    if (SettingsSplitListScope.drawsSidebarOf(context)) {
      // The sidebar of a macOS, Windows or GNOME style split view.
      final Widget? sidebarSection;
      switch (theme.platform) {
        case DevicePlatform.macOS:
          sidebarSection = MacosSidebarSection(
            title: title,
            titlePadding: titlePadding,
            tiles: tiles,
          );
        case DevicePlatform.windows:
          sidebarSection = FluentNavigationSection(
            title: title,
            titlePadding: titlePadding,
            tiles: tiles,
          );
        case DevicePlatform.linux:
          sidebarSection = AdwaitaSidebarSection(
            title: title,
            titlePadding: titlePadding,
            tiles: tiles,
          );
        case DevicePlatform.iOS:
        case DevicePlatform.android:
        case DevicePlatform.fuchsia:
        case DevicePlatform.web:
        // The pure style's list pane is a card list, not a sidebar.
        case DevicePlatform.pure:
        case DevicePlatform.device:
          sidebarSection = null;
      }
      if (sidebarSection != null) {
        final margin = this.margin;
        return margin == null
            ? sidebarSection
            : Padding(padding: margin, child: sidebarSection);
      }
    }

    switch (theme.platform) {
      case DevicePlatform.android:
      case DevicePlatform.fuchsia:
        return AndroidSettingsSection(
          title: title,
          tiles: tiles,
          margin: margin,
          titlePadding: titlePadding,
        );
      case DevicePlatform.linux:
        return AdwaitaSettingsSection(
          title: title,
          tiles: tiles,
          margin: margin,
          titlePadding: titlePadding,
        );
      case DevicePlatform.macOS:
        return MacosSettingsSection(
          title: title,
          tiles: tiles,
          margin: margin,
          titlePadding: titlePadding,
        );
      case DevicePlatform.iOS:
        return IOSSettingsSection(
          title: title,
          tiles: tiles,
          margin: margin,
          titlePadding: titlePadding,
        );
      case DevicePlatform.windows:
        return FluentSettingsSection(
          title: title,
          tiles: tiles,
          margin: margin,
          titlePadding: titlePadding,
        );
      case DevicePlatform.web:
        return WebSettingsSection(
          title: title,
          tiles: tiles,
          margin: margin,
          titlePadding: titlePadding,
        );
      case DevicePlatform.pure:
        return PureSettingsSection(
          title: title,
          tiles: tiles,
          margin: margin,
          titlePadding: titlePadding,
        );
      case DevicePlatform.device:
        throwUnresolvedPlatform('SettingsSection.build');
    }
  }
}
