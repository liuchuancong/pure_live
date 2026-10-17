import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/vendor/tiles/settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_data.dart';

/// The text of a tile's [title] when it is a [Text] or a [RichText] (its
/// semantics label if it has one), or null for other widgets. Internal.
String? tileTitleLabel(Widget? title) {
  if (title is Text) {
    return title.semanticsLabel ??
        title.data ??
        title.textSpan?.toPlainText(includeSemanticsLabels: true);
  }
  if (title is RichText) {
    return title.text.toPlainText(includeSemanticsLabels: true);
  }
  return null;
}

/// Makes a section's [tile] one semantics node, so screen readers read each
/// row on its own. A [SettingsTile] is a node already; any other tile (a
/// `CustomSettingsTile`) gets a node here, or its text would be read with
/// the section title or the rows next to it. Internal.
Widget tileSemanticsNode(Widget tile) =>
    tile is SettingsTile ? tile : Semantics(container: true, child: tile);

/// The node of a [tile] whose row toggles its switch (the Android and web
/// styles). Each tile is one node, or a section's rows would merge into one
/// (a lone tappable row took the text of all the others). The row and the
/// switch both toggle, so a switch tile reads as "title, switch, on"; a
/// tile with onPressed is a button, dimmed when disabled. Internal.
Widget toggleRowSemantics({
  required SettingsTileData tile,
  required bool? selected,
  required Widget child,
}) {
  final isButton = !tile.isSwitch && tile.onPressed != null;
  final node = Semantics(
    container: true,
    button: isButton,
    enabled: isButton || (!tile.isSwitch && !tile.enabled)
        ? tile.enabled
        : null,
    selected: selected,
    child: child,
  );
  return tile.isSwitch ? MergeSemantics(child: node) : node;
}
