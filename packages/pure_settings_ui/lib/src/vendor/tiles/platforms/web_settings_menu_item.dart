import 'package:flutter/material.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_colors.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_data.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_semantics.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';
import 'package:pure_settings_ui/src/vendor/utils/theme_provider.dart';

/// A tile in the list pane of a web-style split view, drawn as an item of
/// Chrome's settings menu: 40px tall, a 20px icon, 14px medium text, and a
/// pill rounded on the end side when selected. Descriptions and values are
/// not shown, as in Chrome's menu. Internal.
class WebSettingsMenuItem extends StatelessWidget {
  const WebSettingsMenuItem(
    this.tile, {
    required this.selected,
    this.semanticsSelected,
    super.key,
  });

  /// Its `trailing` is drawn right after the title, like the external-link
  /// icon of Chrome's "Extensions" item.
  final SettingsTileData tile;
  final bool selected;

  /// Whether assistive technologies hear the item as selected: null for
  /// items that don't open a page.
  final bool? semanticsSelected;

  @override
  Widget build(BuildContext context) =>
      ThemeProvider.withListColorScheme(context, Builder(builder: _buildTile));

  Widget _buildTile(BuildContext context) {
    final theme = SettingsTheme.of(context).themeData;
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);

    final enabled = tile.enabled;
    final iconTheme = IconTheme.of(context).copyWith(
      color: theme.iconColorFor(enabled: enabled, selected: selected),
      size: 20,
    );

    // A disabled item takes no focus, keys or taps (the IgnorePointer below
    // only blocks new pointers).
    final onToggle = enabled ? tile.onToggle : null;
    final onPressed = enabled ? tile.onPressed : null;
    final VoidCallback? onTap = tile.isSwitch
        ? (onToggle == null ? null : () => onToggle(!tile.initialValue))
        : (onPressed == null ? null : () => onPressed(context));

    final item = IgnorePointer(
      ignoring: !enabled,
      child: Padding(
        // cr-nav-menu-item: 1px start margin, 2px end margin.
        padding: const EdgeInsetsDirectional.only(start: 1, end: 2),
        child: Material(
          color: selected
              ? (theme.selectedTileColor ?? Colors.transparent)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadiusDirectional.horizontal(
              end: Radius.circular(100),
            ).resolve(textDirection),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            hoverColor: theme.settingsTileTextColor?.withValues(alpha: 0.06),
            highlightColor: theme.tileHighlightColor,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: textScaler.scale(40)),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: 23,
                  end: 16,
                  top: 10,
                  bottom: 10,
                ),
                child: Row(
                  children: [
                    if (tile.leading != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 20),
                        child: IconTheme(data: iconTheme, child: tile.leading!),
                      ),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: DefaultTextStyle(
                              style:
                                  (theme.tileTextStyle ??
                                          const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ))
                                      .copyWith(
                                        color: theme.titleColorFor(
                                          enabled: enabled,
                                          selected: selected,
                                        ),
                                      ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              child: tile.title,
                            ),
                          ),
                          if (tile.trailing != null)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: 16,
                              ),
                              child: IconTheme(
                                data: iconTheme,
                                child: tile.trailing!,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (tile.isSwitch)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 8),
                        child: SizedBox(
                          height: 20,
                          child: FittedBox(
                            child: Switch(
                              value: tile.initialValue,
                              onChanged: onToggle,
                              activeThumbColor: tile.activeSwitchColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return toggleRowSemantics(
      tile: tile,
      selected: semanticsSelected,
      child: item,
    );
  }
}
