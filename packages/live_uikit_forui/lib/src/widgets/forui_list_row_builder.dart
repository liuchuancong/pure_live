import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/live_uikit.dart';

/// Builds a ForUI list row from a [LanguageListRowSpec] (§9 ListRow).
///
/// `FTile` is the library's own row and carries every part the spec does: `prefix` for
/// [LanguageListRowSpec.leading], `suffix` for [LanguageListRowSpec.trailing], both press
/// handlers, a real `selected` state and the caller's focus node — so the row's hover
/// fill, ink and text roles come from the library's style table rather than from the
/// token approximation. A row with no callbacks stays exactly that: the tile is not
/// hoverable when both are null, so nothing has to be disabled by hand (§9).
///
/// [LanguageListRowSpec.divided] is the one field a lone tile has no slot for — the
/// library puts separators *between* items, through `FTileGroup`, and this contract has
/// no group control to opt into — so the row draws the library's own `FDivider` under
/// itself. That is the same widget a grouped list would paint, not an invented hairline.
abstract final class ForuiListRowBuilder {
  /// Builds the row for [spec].
  static Widget build(BuildContext context, LanguageListRowSpec spec) {
    final row = forui.FTile(
      title: Text(spec.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: spec.subtitle == null ? null : Text(spec.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
      prefix: spec.leading,
      suffix: spec.trailing,
      onPress: spec.onTap,
      onLongPress: spec.onLongPress,
      selected: spec.selected,
      focusNode: spec.focusNode,
      autofocus: spec.autofocus,
    );

    if (!spec.divided) {
      return row;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [row, const forui.FDivider()],
    );
  }
}
