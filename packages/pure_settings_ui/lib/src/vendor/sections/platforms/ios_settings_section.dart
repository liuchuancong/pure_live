import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/vendor/sections/section_header.dart';
import 'package:pure_settings_ui/src/vendor/split/split_scopes.dart';
import 'package:pure_settings_ui/src/vendor/tiles/abstract_settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/tiles/platforms/ios_settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/tiles/settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';

class IOSSettingsSection extends StatelessWidget {
  const IOSSettingsSection({
    required this.tiles,
    required this.margin,
    required this.title,
    this.titlePadding,
    super.key,
  });

  final List<AbstractSettingsTile> tiles;
  final EdgeInsetsDirectional? margin;
  final Widget? title;
  final EdgeInsetsGeometry? titlePadding;

  @override
  Widget build(BuildContext context) {
    final theme = SettingsTheme.of(context);
    final lastTile = tiles.lastOrNull;
    final isLastNonDescriptive =
        lastTile is SettingsTile && lastTile.description == null;
    final textScaler = MediaQuery.textScalerOf(context);
    // In an iPad sidebar the rows are inset 16pt, have no card, and groups
    // are 10pt apart.
    final sidebar = SettingsSplitListScope.maybeOf(context)?.isSplit ?? false;

    return Padding(
      padding:
          margin ??
          (sidebar
              ? EdgeInsets.only(
                  top: title == null ? 0 : textScaler.scale(10),
                  bottom: 10,
                  left: 16,
                  right: 16,
                )
              : EdgeInsets.only(
                  top: textScaler.scale(14.0),
                  bottom: isLastNonDescriptive
                      ? textScaler.scale(27)
                      : textScaler.scale(10),
                  left: 20,
                  right: 20,
                )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            sectionHeader(
              title: title!,
              padding:
                  titlePadding ??
                  EdgeInsetsDirectional.only(
                    start: sidebar ? 14 : 16,
                    bottom: textScaler.scale(8),
                  ),
              style:
                  (theme.themeData.titleTextStyle ??
                          const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ))
                      .copyWith(color: theme.themeData.titleTextColor),
            ),
          buildTileList(sidebar: sidebar),
        ],
      ),
    );
  }

  /// A tile's `description` is a footer under its card, so the tile ends a
  /// card and the next one starts a new card.
  static bool _hasFooter(AbstractSettingsTile tile) =>
      tile is SettingsTile && tile.description != null;

  Widget buildTileList({bool sidebar = false}) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: tiles.length,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (BuildContext context, int index) {
        final isLast = index == tiles.length - 1;
        return IOSSettingsTileAdditionalInfo(
          enableTopBorderRadius: index == 0 || _hasFooter(tiles[index - 1]),
          enableBottomBorderRadius: isLast || _hasFooter(tiles[index]),
          needToShowDivider: !sidebar && !isLast,
          child: tiles[index],
        );
      },
    );
  }
}
