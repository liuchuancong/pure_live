import 'package:flutter/material.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_colors.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_data.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_parts.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_semantics.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';
import 'package:pure_settings_ui/src/vendor/utils/theme_provider.dart';

/// The row of the Android and web styles: an ink well with the leading
/// widget, the title over the value or the description, then the trailing
/// widget or a Material [Switch]. A tap on a switch row toggles. Internal.
class MaterialTileRow extends StatelessWidget {
  const MaterialTileRow({
    required this.tile,
    required this.sideInset,
    required this.switchEndInset,
    required this.titleStyle,
    required this.subtitleStyle,
    this.iconSize,
    this.minHeight,
    this.thumbIcon,
    this.tintsSwitchTrailing = false,
    this.chevron = false,
    this.hideLeading = false,
    this.selected = false,
    this.semanticsSelected,
    super.key,
  });

  final SettingsTileData tile;

  /// Space before the leading widget (or the title, without one) and after
  /// the title.
  final double sideInset;

  /// Space after the switch.
  final double switchEndInset;

  /// Used when the theme has no `tileTextStyle`.
  final TextStyle titleStyle;

  /// Used when the theme has no `tileDescriptionTextStyle`.
  final TextStyle subtitleStyle;

  /// Size of the leading icon; the ambient one when null.
  final double? iconSize;

  /// Minimum row height, scaled with the text.
  final double? minHeight;

  /// Drawn on the switch's thumb.
  final WidgetStateProperty<Icon?>? thumbIcon;

  /// Whether a trailing widget next to the switch gets the icon color.
  final bool tintsSwitchTrailing;

  /// Whether navigation tiles end with a chevron.
  final bool chevron;

  /// Drawn without the leading widget.
  final bool hideLeading;

  /// Drawn as the selected item of a split view's list pane.
  final bool selected;

  /// Whether assistive technologies hear the tile as selected: null for
  /// tiles that don't open a page in a split view's list pane.
  final bool? semanticsSelected;

  @override
  Widget build(BuildContext context) =>
      ThemeProvider.withListColorScheme(context, Builder(builder: _buildTile));

  Widget _buildTile(BuildContext context) {
    final theme = SettingsTheme.of(context).themeData;
    final textScaler = MediaQuery.textScalerOf(context);
    final enabled = tile.enabled;
    final leading = hideLeading ? null : tile.leading;
    final verticalPadding = textScaler.scale(tile.compact ? 6 : 12);

    final selectedSubtitleColor = selected
        ? theme.selectedTileTextColor?.withValues(alpha: 0.78)
        : null;
    final subtitleStyle = (theme.tileDescriptionTextStyle ?? this.subtitleStyle)
        .copyWith(
          color: enabled
              ? selectedSubtitleColor ?? theme.tileDescriptionTextColor
              : theme.inactiveSubtitleColor,
        );

    Widget row = Row(
      children: [
        if (leading != null)
          Padding(
            padding:
                tile.leadingPadding ??
                EdgeInsetsDirectional.only(start: sideInset),
            child: IconTheme(
              data: IconTheme.of(context).copyWith(
                color: theme.iconColorFor(enabled: enabled, selected: selected),
                size: iconSize,
              ),
              child: leading,
            ),
          ),
        Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: leading != null ? 16 : sideInset,
              end: sideInset,
              bottom: verticalPadding,
              top: verticalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                tileText(
                  tile.title,
                  padding: tile.titlePadding ?? EdgeInsets.zero,
                  style: (theme.tileTextStyle ?? titleStyle).copyWith(
                    color: theme.titleColorFor(
                      enabled: enabled,
                      selected: selected,
                    ),
                  ),
                ),
                if (tile.value != null)
                  tileText(
                    tile.value!,
                    padding: const EdgeInsets.only(top: 4.0),
                    style: subtitleStyle,
                  )
                else if (tile.description != null)
                  tileText(
                    tile.description!,
                    padding:
                        tile.descriptionPadding ??
                        const EdgeInsets.only(top: 4.0),
                    style: subtitleStyle,
                  ),
              ],
            ),
          ),
        ),
        ..._buildEnd(context, theme),
      ],
    );
    if (minHeight != null) {
      row = ConstrainedBox(
        constraints: BoxConstraints(minHeight: textScaler.scale(minHeight!)),
        child: row,
      );
    }

    // A disabled tile takes no focus, keys or taps (the IgnorePointer below
    // only blocks new pointers). Neither does a switch tile without
    // onToggle: a tap on its row toggles and never calls onPressed.
    final cantShowAnimation =
        !enabled ||
        (tile.isSwitch ? tile.onToggle == null : tile.onPressed == null);
    return toggleRowSemantics(
      tile: tile,
      selected: semanticsSelected,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Material(
          // AOSP two-pane Settings fills the selected homepage card with the
          // detail pane's color, so it looks joined to it.
          color: selected
              ? (theme.selectedTileColor ?? Colors.transparent)
              : Colors.transparent,
          child: InkWell(
            onTap: cantShowAnimation
                ? null
                : () {
                    if (tile.isSwitch) {
                      tile.onToggle?.call(!tile.initialValue);
                    } else {
                      tile.onPressed?.call(context);
                    }
                  },
            highlightColor: theme.tileHighlightColor,
            child: row,
          ),
        ),
      ),
    );
  }

  /// The end of the row: the switch (after the trailing widget) or the
  /// trailing widget, then the chevron.
  List<Widget> _buildEnd(BuildContext context, SettingsThemeData theme) {
    final enabled = tile.enabled;
    // Trailing icons and the chevron keep their color in a selected tile.
    Widget tinted(Widget child) => IconTheme(
      data: IconTheme.of(context)
          .copyWith(color: theme.iconColorFor(enabled: enabled)),
      child: child,
    );
    late final toggle = Switch(
      value: tile.initialValue,
      onChanged: enabled ? tile.onToggle : null,
      thumbIcon: thumbIcon,
      activeThumbColor: enabled
          ? tile.activeSwitchColor
          : (theme.inactiveSwitchColor ?? theme.inactiveTitleColor),
    );

    return [
      if (tile.isSwitch && tile.trailing != null)
        Row(
          children: [
            tintsSwitchTrailing ? tinted(tile.trailing!) : tile.trailing!,
            Padding(
              padding: EdgeInsetsDirectional.only(end: switchEndInset),
              child: toggle,
            ),
          ],
        )
      else if (tile.isSwitch)
        Padding(
          padding: EdgeInsetsDirectional.only(start: 16, end: switchEndInset),
          child: toggle,
        )
      else if (tile.trailing != null)
        Padding(
          padding:
              tile.trailingPadding ??
              const EdgeInsets.symmetric(horizontal: 16),
          child: tinted(tile.trailing!),
        ),
      if (chevron && tile.isNavigation)
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 8, end: 16),
          child: tinted(
            Icon(
              Icons.chevron_right,
              size: MediaQuery.textScalerOf(context).scale(20),
            ),
          ),
        ),
    ];
  }
}
