import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_data.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_material_row.dart';

class WebSettingsTile extends StatelessWidget {
  const WebSettingsTile(this.tile, {super.key});

  final SettingsTileData tile;

  @override
  Widget build(BuildContext context) => MaterialTileRow(
    tile: tile,
    sideInset: 20,
    switchEndInset: 8,
    titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
    subtitleStyle: const TextStyle(fontSize: 13),
    iconSize: 20,
    minHeight: 48,
    tintsSwitchTrailing: true,
    // Chrome shows a chevron on rows that open a sub-page.
    chevron: true,
  );
}
