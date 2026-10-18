import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_palette.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_style.dart';
import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart' show DevicePlatform;

/// ForUI's settings theme.
///
/// `FCard` is a real surface carrying `FTheme`'s radius, and `FTile` is the
/// library's own row: it paints its hover fill, its ink and its text roles from
/// `FTileGroup`'s table and separates its items with `FDivider`. So the rows go
/// edge to edge — a group whose members are inset would show the card's rounded
/// corners as clipped rectangles behind them — and the separators are the
/// library's, not an invented hairline.
///
/// forui's palette is the library's, not the token's. `FThemeData` has a private
/// constructor and the supported path for a custom palette is generating a theme
/// file, so the host chooses only the light or the neutral-dark variant and the
/// card and rows keep forui's greys. Only the page behind them comes from the
/// token, which is why changing the accent moves the background under a card
/// that does not move.
///
/// A selected row is forui's own state; the card adds no fill to it.
const foruiSettingsLanguage = SettingsLanguage(
  platform: DevicePlatform.pure,
  style: PureSettingsStyle(
    palette: pureSettingsPalette,
    cardPadding: EdgeInsets.zero,
    cardBordered: false,
    rowDividers: true,
  ),
);
