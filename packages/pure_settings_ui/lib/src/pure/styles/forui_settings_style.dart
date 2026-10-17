import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_style.dart';
import 'package:pure_settings_ui/src/pure/styles/pure_settings_base_style.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// ForUI's settings style.
///
/// `FCard` is a real surface with `FTheme`'s own radius, and `FTile` is the
/// library's own row: it paints its hover fill, its ink and its text roles from
/// `FTileGroup`'s table, and separates its items with `FDivider`. So the rows
/// go edge to edge — a group whose members are inset would show the card's
/// rounded corners as clipped rectangles behind them — and the separators are
/// the library's, not an invented hairline.
///
/// forui's palette is the library's, not the token's: `FThemeData` has a private
/// constructor and its supported path for a custom palette is generating a
/// theme file, so the host picks only the light or the neutral-dark variant and
/// the card and rows keep forui's greys. Only the page behind them comes from
/// the token, which is why an accent change moves the background under a card
/// that does not move.
const PureSettingsStyle foruiSettingsStyle = PureSettingsStyle(
  name: 'forui',
  palette: pureSettingsTokenPalette,
  cardPadding: EdgeInsets.zero,
  rowDividers: true,
  tintsSelectedCard: false,
);
