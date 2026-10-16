import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';

/// Builds a Cupertino list row from a [LanguageListRowSpec] (§9 ListRow).
///
/// `cu.CupertinoListTile` is the iOS settings row: leading, title, subtitle and
/// trailing map directly, and its own pressed background is the library's answer
/// to a row that responds to a tap.
///
/// Two fields have no slot on the tile and are handled rather than dropped:
/// [LanguageListRowSpec.onLongPress] (iOS rows do not long-press, so a gesture
/// wrapper recognises it without changing how the tile looks) and
/// [LanguageListRowSpec.selected] (the tile takes a background colour, which is
/// where the token selection fill goes). [LanguageListRowSpec.divided] draws the
/// hairline itself — a bare tile has no separator concept outside a
/// `CupertinoListSection`.
abstract final class CupertinoListRowBuilder {
  /// Builds the row for [spec].
  static Widget build(BuildContext context, LanguageListRowSpec spec) {
    final theme = LiveTheme.of(context);
    Widget tile = cu.CupertinoListTile(
      leading: spec.leading,
      title: Text(spec.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: spec.subtitle == null ? null : Text(spec.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: spec.trailing,
      onTap: spec.onTap,
      backgroundColor: spec.selected ? theme.listTile.selectedBackground : null,
    );

    if (spec.onLongPress != null) {
      tile = GestureDetector(behavior: HitTestBehavior.translucent, onLongPress: spec.onLongPress, child: tile);
    }

    if (!spec.divided) {
      return tile;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        tile,
        Container(
          height: theme.token.motion.lineWidth,
          color: theme.listTile.dividerColor,
          margin: const EdgeInsets.only(left: 16),
        ),
      ],
    );
  }
}
