import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/vendor/tiles/settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_semantics.dart';

/// What a [SettingsTile] hands to the tile or the sidebar row of its style:
/// its own fields, with [onPressed] already followed by opening the
/// destination and a null `initialValue` read as off. Internal.
@immutable
class SettingsTileData {
  const SettingsTileData({
    required this.tileType,
    required this.leading,
    required this.title,
    required this.titleDescription,
    required this.description,
    required this.onPressed,
    required this.onToggle,
    required this.value,
    required this.initialValue,
    required this.activeSwitchColor,
    required this.enabled,
    required this.trailing,
    required this.compact,
    required this.titlePadding,
    required this.leadingPadding,
    required this.trailingPadding,
    required this.descriptionPadding,
    required this.titleDescriptionPadding,
  });

  final SettingsTileType tileType;
  final Widget? leading;
  final Widget title;
  final Widget? titleDescription;
  final Widget? description;
  final void Function(BuildContext context)? onPressed;
  final void Function(bool value)? onToggle;
  final Widget? value;
  final bool initialValue;
  final Color? activeSwitchColor;
  final bool enabled;
  final Widget? trailing;
  final bool compact;
  final EdgeInsetsGeometry? titlePadding;
  final EdgeInsetsGeometry? leadingPadding;
  final EdgeInsetsGeometry? trailingPadding;
  final EdgeInsetsGeometry? descriptionPadding;
  final EdgeInsetsGeometry? titleDescriptionPadding;

  bool get isSwitch => tileType == SettingsTileType.switchTile;

  bool get isNavigation => tileType == SettingsTileType.navigationTile;

  /// The switch ([child]) of a row with an action of its own ([onPressed] on
  /// iOS, macOS and Windows, in lists and in sidebars): the row and the
  /// switch are then separate semantics nodes, and the switch would read as
  /// just "switch, on". It becomes one node that says what it switches: the
  /// title (see [tileTitleLabel]), then the switch state.
  Widget labelSwitchIfSeparate(Widget child) => onPressed == null
      ? child
      : MergeSemantics(
          child: Semantics(label: tileTitleLabel(title), child: child),
        );
}
