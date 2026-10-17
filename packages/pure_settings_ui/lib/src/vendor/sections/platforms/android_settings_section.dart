import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/vendor/sections/section_header.dart';
import 'package:pure_settings_ui/src/vendor/tiles/abstract_settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_semantics.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';
import 'package:pure_settings_ui/src/vendor/utils/theme_provider.dart';

class AndroidSettingsSection extends StatelessWidget {
  const AndroidSettingsSection({
    required this.tiles,
    required this.margin,
    this.title,
    this.titlePadding,
    super.key,
  });

  final List<AbstractSettingsTile> tiles;
  final EdgeInsetsDirectional? margin;
  final Widget? title;
  final EdgeInsetsGeometry? titlePadding;

  @override
  Widget build(BuildContext context) {
    return ThemeProvider.withListColorScheme(
      context,
      buildSectionBody(context),
    );
  }

  Widget buildSectionBody(BuildContext context) {
    final theme = SettingsTheme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            // A heading of its own, like a PreferenceCategory title.
            sectionHeader(
              title: title!,
              padding:
                  titlePadding ??
                  EdgeInsetsDirectional.only(
                    top: textScaler.scale(24),
                    bottom: textScaler.scale(8),
                    start: 24,
                    end: 24,
                  ),
              style:
                  (theme.themeData.titleTextStyle ??
                          const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ))
                      .copyWith(color: theme.themeData.titleTextColor),
            )
          else
            SizedBox(height: textScaler.scale(16)),
          buildTileList(theme),
        ],
      ),
    );
  }

  /// Android 16+ settings put each tile on its own card: 2dp apart, with
  /// large corners at the ends of the group and small ones in between.
  Widget buildTileList(SettingsTheme theme) {
    const outer = Radius.circular(20);
    const inner = Radius.circular(4);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var i = 0; i < tiles.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 2),
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: i == 0 ? outer : inner,
                  bottom: i == tiles.length - 1 ? outer : inner,
                ),
                child: ColoredBox(
                  color:
                      theme.themeData.settingsSectionBackground ??
                      const Color(0x00000000),
                  child: tileSemanticsNode(tiles[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
