import 'package:flutter/material.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_data.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_material_row.dart';

/// Pixel settings switches show a check when on and a cross when off.
final _thumbIcon = WidgetStateProperty.resolveWith<Icon>(
  (states) =>
      Icon(states.contains(WidgetState.selected) ? Icons.check : Icons.close),
);

class AndroidSettingsTile extends StatelessWidget {
  const AndroidSettingsTile(
    this.tile, {
    this.hideLeading = false,
    this.selected = false,
    this.semanticsSelected,
    super.key,
  });

  final SettingsTileData tile;

  /// Drawn without the leading widget: a split view's list pane that is too
  /// narrow for icons.
  final bool hideLeading;

  /// Drawn as the selected item of a split view's list pane.
  final bool selected;

  /// Whether assistive technologies hear the tile as selected: null for
  /// tiles that don't open a page in a split view's list pane.
  final bool? semanticsSelected;

  @override
  Widget build(BuildContext context) => MaterialTileRow(
    tile: tile,
    sideInset: 16,
    switchEndInset: 12,
    titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
    subtitleStyle: const TextStyle(),
    thumbIcon: _thumbIcon,
    hideLeading: hideLeading,
    selected: selected,
    semanticsSelected: semanticsSelected,
  );
}
