import 'package:flutter/material.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_metrics.dart';
import 'package:pure_settings_ui/src/pure/pure_text_slot.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_data.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_parts.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// Tells a row of the pure style whether its section draws a divider under it.
///
/// A row cannot know its own index, and pure_uikit's row takes the divider as a
/// flag so it can draw its own library's separator — forui's `FDivider`,
/// glass's `GlassDivider`, the hairline the neumorphic and wind compositions
/// paint themselves — instead of this package inventing one. So the section
/// states it per row, the way the iOS style states its own border flags.
class PureSettingsRowScope extends InheritedWidget {
  /// A scope telling [child] whether a divider belongs under it.
  const new({required this.divided, required super.child, super.key});

  /// Whether the row draws a divider under itself.
  final bool divided;

  /// The flag of the nearest scope, or false outside one — a tile used on its
  /// own is a tile with nothing under it to separate.
  static bool dividedOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PureSettingsRowScope>()?.divided ?? false;

  @override
  bool updateShouldNotify(PureSettingsRowScope oldWidget) => divided != oldWidget.divided;
}

/// One settings row of the pure style: pure_uikit's own [PureListRow], which
/// reads the active design language and constructs that library's real row.
///
/// The slots are mapped rather than passed through, because a row's parts are
/// strings in pure_uikit and widgets in settings_ui:
///
/// - `title` is the row's title, `titleDescription` its subtitle, falling back
///   to `description`. Both show, and `value` still goes at the end of the row,
///   which is what the iOS, macOS, Windows and GNOME styles do — the Android
///   and web styles hide a description when a value is set, and this style has
///   no reason to.
/// - `value` is grey text at the end of the row, `trailing` follows it, and a
///   navigation tile ends in a chevron that mirrors in RTL.
/// - a switch tile's trailing slot is a [PureSwitch], and tapping anywhere on
///   the row flips it, as it does in the Android, GNOME and web styles.
///
/// A slot holding something other than a [Text] falls back to
/// [_PureWidgetRow], so an inline icon or a badge in a title still renders.
class PureSettingsTile extends StatelessWidget {
  /// A row drawing [tile].
  const new(
    this.tile, {
    this.hideLeading = false,
    this.selected = false,
    this.semanticsSelected,
    super.key,
  });

  /// The tile's fields, with its destination already folded into `onPressed`.
  final SettingsTileData tile;

  /// Drawn without the leading widget: a split view's list pane that is too
  /// narrow for icons.
  final bool hideLeading;

  /// Drawn as the selected item of a split view's list pane.
  final bool selected;

  /// Whether assistive technologies hear the tile as selected: null for tiles
  /// that don't open a page in a split view's list pane.
  final bool? semanticsSelected;

  /// The opacity of a row whose [SettingsTileData.enabled] is false.
  ///
  /// pure_uikit's row has no disabled state of its own — each library greys its
  /// own controls differently and a row is not one of them — so the whole row
  /// dims, which is also what the GNOME style does.
  static const double _disabledOpacity = 0.5;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsTheme.of(context).themeData;
    final onTap = _tap(context);
    final trailing = _trailing(context, settings);
    final leading = hideLeading ? null : tile.leading;
    final textual = pureSlotsAreText([tile.title, tile.titleDescription, tile.description, tile.value]);

    final row = textual
        ? PureListRow(
            title: pureTextOf(tile.title) ?? '',
            subtitle: pureTextOf(tile.titleDescription) ?? pureTextOf(tile.description),
            leading: leading,
            trailing: trailing,
            onTap: onTap,
            selected: selected,
            divided: PureSettingsRowScope.dividedOf(context),
          )
        : _PureWidgetRow(
            tile: tile,
            leading: leading,
            trailing: trailing,
            onTap: onTap,
            selected: selected,
            divided: PureSettingsRowScope.dividedOf(context),
          );

    return Semantics(
      selected: semanticsSelected,
      enabled: tile.enabled,
      // A switch tile is a toggle, not a button: announcing both would assert
      // two different things about the same node.
      button: onTap != null && !tile.isSwitch,
      child: tile.enabled ? row : Opacity(opacity: _disabledOpacity, child: row),
    );
  }

  /// What a tap on the row does: flip the switch, or run the tile's action.
  ///
  /// Null when the row is inert — disabled, or a switch with no `onToggle`,
  /// which is how settings_ui spells a disabled switch — so pure_uikit's row
  /// draws itself non-interactive rather than swallowing the tap.
  VoidCallback? _tap(BuildContext context) {
    if (!tile.enabled) return null;
    if (tile.isSwitch) {
      final onToggle = tile.onToggle;
      return onToggle == null ? null : () => onToggle(!tile.initialValue);
    }
    final onPressed = tile.onPressed;
    return onPressed == null ? null : () => onPressed(context);
  }

  /// The row's end: the switch, or the value, the caller's trailing widget and
  /// the navigation chevron, in that order.
  Widget? _trailing(BuildContext context, SettingsThemeData settings) {
    if (tile.isSwitch) {
      return tile.labelSwitchIfSeparate(
        PureSwitch(value: tile.initialValue, onChanged: tile.enabled ? tile.onToggle : null),
      );
    }
    final value = tile.value;
    final parts = <Widget>[
      if (value != null)
        tileValue(
          value,
          style: (settings.tileDescriptionTextStyle ?? const TextStyle()).copyWith(
            color: settings.trailingTextColor,
          ),
          maxWidth: pureSettingsValueMaxWidth,
        ),
      if (tile.trailing != null) tile.trailing!,
      if (tile.isNavigation) _PureChevron(color: settings.leadingIconsColor),
    ];
    if (parts.isEmpty) return null;
    if (parts.length == 1) return parts.single;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < parts.length; index++) ...[
          if (index > 0) const SizedBox(width: PureSpacing.sm),
          parts[index],
        ],
      ],
    );
  }
}

/// The chevron of a navigation row, mirrored in RTL.
///
/// An [Icon] does not flip with the text direction, so the glyph is chosen
/// rather than transformed: a leading edge is a leading edge in both
/// directions, and a rotated chevron would point out of the row.
class _PureChevron extends StatelessWidget {
  const new({this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) => Icon(
    Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
    color: color,
    size: PureSizing.iconSm,
  );
}

/// The row drawn when a slot holds something other than a [Text].
///
/// pure_uikit's row takes strings, so a widget slot cannot cross into it. This
/// builds the same row out of pure_uikit's own interaction layer instead: a
/// [PureBox] for the hover, press, focus and selection states, the vendor's
/// [tileTitleColumn] for the three text slots with their own paddings, and the
/// token's list-row colours. It is plainer than the library's real row — no
/// `FTile` hover fill, no frosted sheet — but it renders every slot, which is
/// the alternative to dropping one.
class _PureWidgetRow extends StatelessWidget {
  const new({
    required this.tile,
    required this.leading,
    required this.trailing,
    required this.onTap,
    required this.selected,
    required this.divided,
  });

  final SettingsTileData tile;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final bool divided;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final settings = SettingsTheme.of(context).themeData;
    final listTile = theme.listTile;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PureBox(
          style: (state) => Style(
            background: switch (state) {
              InteractionState.hovered => listTile.hoverBackground,
              InteractionState.pressed => settings.tileHighlightColor,
              _ => selected ? listTile.selectedBackground : null,
            },
          ),
          onTap: onTap,
          enabled: tile.enabled,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PureSpacing.lg, vertical: PureSpacing.md),
            child: Row(
              children: [
                if (leading != null) ...[leading!, SizedBox(width: listTile.gap)],
                Expanded(
                  child: tileTitleColumn(
                    tile: tile,
                    titleStyle: (settings.tileTextStyle ?? theme.text.body).copyWith(
                      color: settings.settingsTileTextColor,
                    ),
                    subtitleStyle: (settings.tileDescriptionTextStyle ?? theme.text.caption).copyWith(
                      color: settings.tileDescriptionTextColor,
                    ),
                    subtitlePadding: const EdgeInsets.only(top: PureSpacing.xxs),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: PureSpacing.md), trailing!],
              ],
            ),
          ),
        ),
        if (divided)
          ColoredBox(
            color: settings.dividerColor ?? theme.colors.borderSecondary,
            child: const SizedBox(height: 1, width: double.infinity),
          ),
      ],
    );
  }
}
