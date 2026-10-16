import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a Material UI list row from a [LanguageListRowSpec] (§9 ListRow).
///
/// `material_ui`'s `ListTile` covers every field the contract carries — leading,
/// title, subtitle, trailing, both press handlers, the selected state and focus —
/// so the row is the library's own: its ink splash, its state layers and its
/// text roles come from `mu.Theme`. A row with no tap is passed as disabled
/// rather than left looking tappable.
///
/// [LanguageListRowSpec.divided] is the one field the tile has no slot for (a
/// Material list puts its separators between items), so it draws the library's
/// own `Divider` under the tile rather than being dropped.
abstract final class MaterialListRowBuilder {
  /// Builds the row for [spec].
  static Widget build(BuildContext context, LanguageListRowSpec spec) {
    final theme = LiveTheme.of(context);
    final tile = mu.ListTile(
      leading: spec.leading,
      title: Text(spec.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: spec.subtitle == null ? null : Text(spec.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: spec.trailing,
      onTap: spec.onTap,
      onLongPress: spec.onLongPress,
      selected: spec.selected,
      selectedColor: spec.selected ? theme.colors.primary : null,
      enabled: spec.onTap != null || spec.onLongPress != null,
      focusNode: spec.focusNode,
      autofocus: spec.autofocus,
    );

    if (!spec.divided) {
      return tile;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        tile,
        mu.Divider(
          height: theme.token.motion.lineWidth * 2,
          thickness: theme.token.motion.lineWidth,
          color: theme.listTile.dividerColor,
        ),
      ],
    );
  }
}
