import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_data.dart';

// Pieces that the tiles of several styles are built from. Internal.

/// A text of a tile ([child]) in [style], inside [padding].
Widget tileText(
  Widget child, {
  required EdgeInsetsGeometry padding,
  required TextStyle style,
}) => Padding(
  padding: padding,
  child: DefaultTextStyle(style: style, child: child),
);

/// The title of [tile] over its subtitles: the `titleDescription`, then
/// (unless the style shows it elsewhere) the `description`.
/// [subtitlePadding] is the default padding of each subtitle.
Widget tileTitleColumn({
  required SettingsTileData tile,
  required TextStyle titleStyle,
  required TextStyle subtitleStyle,
  required EdgeInsetsGeometry subtitlePadding,
  bool showDescription = true,
}) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    tileText(
      tile.title,
      padding: tile.titlePadding ?? EdgeInsets.zero,
      style: titleStyle,
    ),
    if (tile.titleDescription != null)
      tileText(
        tile.titleDescription!,
        padding: tile.titleDescriptionPadding ?? subtitlePadding,
        style: subtitleStyle,
      ),
    if (showDescription && tile.description != null)
      tileText(
        tile.description!,
        padding: tile.descriptionPadding ?? subtitlePadding,
        style: subtitleStyle,
      ),
  ],
);

/// A tile's [value] at the end of its row: one line that keeps its natural
/// width up to [maxWidth] (half the row), so neither a long title nor a long
/// value hides the other.
Widget tileValue(
  Widget value, {
  required TextStyle style,
  required double maxWidth,
}) => ConstrainedBox(
  constraints: BoxConstraints(maxWidth: maxWidth),
  child: DefaultTextStyle(
    style: style,
    overflow: TextOverflow.ellipsis,
    maxLines: 1,
    textAlign: TextAlign.end,
    child: value,
  ),
);
