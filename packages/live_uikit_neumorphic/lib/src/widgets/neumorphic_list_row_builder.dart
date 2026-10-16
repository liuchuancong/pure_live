import 'package:flutter/services.dart' show KeyUpEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Neumorphic list row from a [LanguageListRowSpec] (§9 ListRow).
///
/// **Composed, not mapped.** `flutter_neumorphic_ui_kit` ships no list tile: its
/// widgets are surfaces a caller places (container, card, button, field, switch,
/// slider, app bar, bottom nav), and `NeuCard` is the wrong one for a row — it is
/// an embossed plane at `depth * 1.25` whose whole job is to stand apart from the
/// page, which is not what a row in a list means. So the row is assembled from the
/// library's own face and its own theme values.
///
/// Selection is stated the way this style states every active thing — with depth,
/// not with a fill: the token's `selectedBackground` has no place on a soft surface,
/// so a selected row sinks into [neu.NeuShape.pressed] and lifts its title in
/// [neu.NeuThemeData.accentColor], the same dish the nav bar's active destination
/// and the segmented track use. An idle row is a flat plane at zero depth, which is
/// the page itself: the row is a place in a list, not a card.
///
/// Handled rather than dropped, field by field:
/// - [LanguageListRowSpec.leading] and [LanguageListRowSpec.trailing] sit before and
///   after the text column, which takes the remaining width.
/// - [LanguageListRowSpec.subtitle] is the second line, in the token's secondary text
///   role and the library's caption size.
/// - [LanguageListRowSpec.onTap] and [LanguageListRowSpec.onLongPress] both go into
///   one gesture layer over the whole plane, so an `onTap`-only caller is not
///   quietly stripped of a long press and a long-press-only caller keeps its callback.
/// - [LanguageListRowSpec.focusNode] and [LanguageListRowSpec.autofocus] are honoured
///   by a [Focus] wrapper — the library has no concept of focus at all, so the node
///   is carried by the core's own plumbing and Space/Enter/NumpadEnter/Select activate
///   the row the way a tap does. A row with no `onTap` cannot take focus.
/// - [LanguageListRowSpec.divided] draws the hairline itself, at the token's line
///   width and the list-row divider colour, because a Neumorphic surface has no
///   divider of its own to borrow.
abstract final class NeumorphicListRowBuilder {
  /// Builds the row for [spec].
  static Widget build(BuildContext context, LanguageListRowSpec spec) {
    final theme = LiveTheme.of(context);
    final surface = neu.NeuTheme.of(context);
    final listTile = theme.listTile;
    final leading = spec.leading;
    final trailing = spec.trailing;
    final subtitle = spec.subtitle;

    final row = neu.NeuContainer(
      shape: spec.selected ? neu.NeuShape.pressed : neu.NeuShape.flat,
      baseColor: surface.baseColor,
      borderRadius: surface.borderRadius,
      depth: spec.selected ? surface.depth : 0.0,
      distance: spec.selected ? surface.distance : 0.0,
      padding: EdgeInsets.symmetric(
        horizontal: listTile.paddingHorizontal,
        vertical: listTile.textPaddingVertical,
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading, SizedBox(width: listTile.gap)],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.text.body.copyWith(
                    color: spec.selected ? surface.accentColor : theme.colors.text,
                    fontWeight: spec.selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: listTile.gap / 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[SizedBox(width: listTile.gap), trailing],
        ],
      ),
    );

    final pressable = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: spec.onTap,
      onLongPress: spec.onLongPress,
      child: row,
    );

    final focusable = Focus(
      focusNode: spec.focusNode,
      autofocus: spec.autofocus,
      canRequestFocus: spec.onTap != null,
      onKeyEvent: (node, event) {
        if (event is! KeyUpEvent) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.select) {
          spec.onTap?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: pressable,
    );

    if (!spec.divided) {
      return focusable;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        focusable,
        Container(height: theme.token.motion.lineWidth, color: listTile.dividerColor),
      ],
    );
  }
}
