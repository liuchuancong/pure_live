import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/split/settings_destination.dart';
import 'package:pure_settings_ui/src/vendor/split/adwaita_split.dart';
import 'package:pure_settings_ui/src/vendor/split/fluent_split.dart';
import 'package:pure_settings_ui/src/vendor/split/macos_split.dart';
import 'package:pure_settings_ui/src/vendor/split/settings_destination_page.dart';
import 'package:pure_settings_ui/src/vendor/split/split_scopes.dart';
import 'package:pure_settings_ui/src/vendor/tiles/abstract_settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/tiles/platforms/adwaita_settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/tiles/platforms/android_settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/tiles/platforms/fluent_settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/tiles/platforms/ios_settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/tiles/platforms/macos_settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/tiles/platforms/web_settings_menu_item.dart';
import 'package:pure_settings_ui/src/vendor/tiles/platforms/web_settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_data.dart';
import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';
import 'package:pure_settings_ui/src/vendor/utils/unresolved_platform.dart';

enum SettingsTileType { simpleTile, switchTile, navigationTile }

class SettingsTile extends AbstractSettingsTile {
  SettingsTile({
    this.leading,
    this.trailing,
    this.value,
    required this.title,
    this.titleDescription,
    this.description,
    this.onPressed,
    this.enabled = true,
    this.compact = false,
    this.titlePadding,
    this.leadingPadding,
    this.trailingPadding,
    this.descriptionPadding,
    this.titleDescriptionPadding,
    super.key,
  }) : destination = null {
    onToggle = null;
    initialValue = null;
    activeSwitchColor = null;
    tileType = SettingsTileType.simpleTile;
  }

  SettingsTile.navigation({
    this.leading,
    this.trailing,
    this.value,
    required this.title,
    this.titleDescription,
    this.description,
    this.onPressed,
    this.enabled = true,
    this.compact = false,
    this.titlePadding,
    this.leadingPadding,
    this.trailingPadding,
    this.descriptionPadding,
    this.titleDescriptionPadding,
    this.destination,
    super.key,
  }) {
    onToggle = null;
    initialValue = null;
    activeSwitchColor = null;
    tileType = SettingsTileType.navigationTile;
  }

  SettingsTile.switchTile({
    required this.initialValue,
    required this.onToggle,
    this.activeSwitchColor,
    this.leading,
    this.trailing,
    required this.title,
    this.titleDescription,
    this.description,
    this.onPressed,
    this.enabled = true,
    this.compact = false,
    this.titlePadding,
    this.leadingPadding,
    this.trailingPadding,
    this.descriptionPadding,
    this.titleDescriptionPadding,
    super.key,
  }) : destination = null {
    value = null;
    tileType = SettingsTileType.switchTile;
  }

  /// The widget at the beginning of the tile
  final Widget? leading;

  /// The Widget at the end of the tile
  final Widget? trailing;

  /// The widget at the center of the tile
  final Widget title;

  /// A second line under the title, inside the row. Shown in the iOS,
  /// macOS, Windows and GNOME styles only.
  final Widget? titleDescription;

  /// Secondary text: a footer under the card in the iOS and macOS styles,
  /// text under the title inside the row elsewhere (in the Android and web
  /// styles only when [value] is null).
  final Widget? description;

  /// Called with the tile's context when the row is tapped, unless [enabled]
  /// is false. On switch tiles it runs for taps beside the switch in the
  /// iOS, macOS and Windows styles, and never in the Android, GNOME and web
  /// styles (a row tap toggles).
  final void Function(BuildContext context)? onPressed;

  /// When true, reduces the tile's vertical padding by half for a more
  /// compact appearance in dense settings lists.
  final bool compact;

  /// Replaces the default padding around [title].
  final EdgeInsetsGeometry? titlePadding;

  /// Replaces the default padding around [leading].
  final EdgeInsetsGeometry? leadingPadding;

  /// Replaces the default padding around [trailing]. Not used on switch
  /// tiles in the Android and web styles.
  final EdgeInsetsGeometry? trailingPadding;

  /// Replaces the default padding around [description].
  final EdgeInsetsGeometry? descriptionPadding;

  /// Replaces the default padding around [titleDescription]. The Android and
  /// web styles don't show [titleDescription].
  final EdgeInsetsGeometry? titleDescriptionPadding;

  /// The page this navigation tile opens (set with
  /// [SettingsTile.navigation]).
  ///
  /// A tap calls [onPressed] first, if set, then opens the page: in a
  /// [SettingsList] it pushes a platform route (Cupertino in the iOS, macOS
  /// and GNOME styles, Material otherwise) with the package's page header
  /// over the body; in the list pane of a [SettingsSplitView] it shows the
  /// page in the detail pane, and the tile is drawn selected while its page
  /// shows there.
  final SettingsDestination? destination;

  late final Color? activeSwitchColor;
  late final Widget? value;
  late final void Function(bool value)? onToggle;
  late final SettingsTileType tileType;
  late final bool? initialValue;
  late final bool enabled;

  /// [onPressed], followed by opening [destination].
  void Function(BuildContext context)? get _effectiveOnPressed {
    final destination = this.destination;
    if (destination == null) return onPressed;
    return (BuildContext context) {
      onPressed?.call(context);
      if (!context.mounted) return;
      openSettingsDestination(
        context,
        destination: destination,
        tileTitle: title,
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    final listPane = SettingsSplitListScope.maybeOf(context);
    final destination = this.destination;
    if (listPane != null && destination != null) {
      listPane.onTileBuilt?.call(destination, title);
    }
    final inSplitListPane = listPane != null && listPane.isSplit;
    final selected = listPane?.isSelected(destination) ?? false;
    // Tiles and sidebar rows are semantics containers that say themselves
    // whether they are selected: an annotation around them would land on
    // their section's node.
    final semanticsSelected = inSplitListPane && destination != null
        ? selected
        : null;
    final platform = SettingsTheme.of(context).platform;
    final tile = SettingsTileData(
      tileType: tileType,
      leading: leading,
      title: title,
      titleDescription: titleDescription,
      description: description,
      onPressed: _effectiveOnPressed,
      onToggle: onToggle,
      value: value,
      initialValue: initialValue ?? false,
      activeSwitchColor: activeSwitchColor,
      enabled: enabled,
      trailing: trailing,
      compact: compact,
      titlePadding: titlePadding,
      leadingPadding: leadingPadding,
      trailingPadding: trailingPadding,
      descriptionPadding: descriptionPadding,
      titleDescriptionPadding: titleDescriptionPadding,
    );

    if (listPane != null && listPane.sidebar) {
      // The row of a macOS, Windows or GNOME sidebar. The other styles
      // draw their usual tiles in the list pane.
      switch (platform) {
        case DevicePlatform.macOS:
          return MacosSidebarItem(
            tile,
            selected: selected,
            semanticsSelected: semanticsSelected,
            opensPage: destination != null,
          );
        case DevicePlatform.windows:
          return FluentNavigationItem(
            tile,
            id: destination?.id,
            selected: selected,
            semanticsSelected: semanticsSelected,
          );
        case DevicePlatform.linux:
          return AdwaitaSidebarRow(
            tile,
            selected: selected,
            semanticsSelected: semanticsSelected,
          );
        case DevicePlatform.iOS:
        case DevicePlatform.android:
        case DevicePlatform.fuchsia:
        case DevicePlatform.web:
        // The pure style draws its usual rows in a list pane.
        case DevicePlatform.pure:
        case DevicePlatform.device:
          break;
      }
    }

    switch (platform) {
      case DevicePlatform.android:
      case DevicePlatform.fuchsia:
        return AndroidSettingsTile(
          tile,
          hideLeading: inSplitListPane && listPane.hideLeading,
          selected: selected,
          semanticsSelected: semanticsSelected,
        );
      case DevicePlatform.linux:
        return AdwaitaSettingsTile(tile);
      case DevicePlatform.macOS:
        return MacosSettingsTile(tile);
      case DevicePlatform.iOS:
        return IOSSettingsTile(
          tile,
          selected: selected,
          sidebar: inSplitListPane,
          semanticsSelected: semanticsSelected,
        );
      case DevicePlatform.windows:
        return FluentSettingsTile(tile);
      case DevicePlatform.web:
        if (inSplitListPane) {
          return WebSettingsMenuItem(
            tile,
            selected: selected,
            semanticsSelected: semanticsSelected,
          );
        }
        return WebSettingsTile(tile);
      case DevicePlatform.pure:
        return PureSettingsTile(
          tile,
          hideLeading: inSplitListPane && listPane.hideLeading,
          selected: selected,
          semanticsSelected: semanticsSelected,
        );
      case DevicePlatform.device:
        throwUnresolvedPlatform('SettingsTile.build');
    }
  }
}
