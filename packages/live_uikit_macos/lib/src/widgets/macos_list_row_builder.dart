import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Builds a macOS list row from a [LanguageListRowSpec] (§9 ListRow).
///
/// `MacosListTile` is the closest match and takes both press callbacks, so
/// [LanguageListRowSpec.onTap] and [LanguageListRowSpec.onLongPress] map
/// directly — the gesture wrapper this adapter's card needs is not required
/// here.
///
/// Two fields have no slot on the library's tile and are composed rather than
/// dropped: [LanguageListRowSpec.trailing] (macOS rows end at their text, while
/// a settings row commonly carries a chevron or a switch) sits beside the tile
/// in a row, and [LanguageListRowSpec.selected] is painted as the row's own
/// fill. [LanguageListRowSpec.divided] draws the hairline itself.
abstract final class MacosListRowBuilder {
  /// Builds the row for [spec].
  static Widget build(BuildContext context, LanguageListRowSpec spec) {
    final theme = LiveTheme.of(context);
    final secondary = theme.colors.textSecondary;

    Widget tile = macos.MacosListTile(
      leading: spec.leading,
      title: Text(spec.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: spec.subtitle == null
          ? null
          : Text(
              spec.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle().copyWith(color: secondary),
            ),
      onClick: spec.onTap,
      onLongPress: spec.onLongPress,
      mouseCursor: spec.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
    );

    if (spec.selected) {
      tile = DecoratedBox(
        decoration: BoxDecoration(color: theme.listTile.selectedBackground),
        child: tile,
      );
    }

    final trailing = spec.trailing;
    var row = tile;
    if (trailing != null) {
      row = Row(
        children: [
          Expanded(child: tile),
          SizedBox(width: theme.listTile.gap),
          trailing,
        ],
      );
    }

    if (!spec.divided) {
      return row;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        Container(height: theme.token.motion.lineWidth, color: theme.listTile.dividerColor),
      ],
    );
  }
}
