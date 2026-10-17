import 'package:flutter/material.dart';
import 'package:pure_settings_ui/src/vendor/sections/section_header.dart';
import 'package:pure_settings_ui/src/vendor/split/split_scopes.dart';
import 'package:pure_settings_ui/src/vendor/tiles/abstract_settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_semantics.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';
import 'package:pure_settings_ui/src/vendor/utils/theme_provider.dart';

class WebSettingsSection extends StatelessWidget {
  const WebSettingsSection({
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
    return ThemeProvider.withListColorScheme(
      context,
      buildSectionBody(context),
    );
  }

  Widget buildSectionBody(BuildContext context) {
    final theme = SettingsTheme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);

    // The list pane of a split view is Chrome's menu: no cards.
    if (SettingsSplitListScope.maybeOf(context)?.isSplit ?? false) {
      return Padding(
        padding: margin ?? EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              sectionHeader(
                title: title!,
                padding:
                    titlePadding ??
                    EdgeInsetsDirectional.only(
                      start: 24,
                      end: 16,
                      top: textScaler.scale(8),
                      bottom: textScaler.scale(4),
                    ),
                style:
                    (theme.themeData.titleTextStyle ??
                            const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ))
                        .copyWith(
                          color: theme.themeData.tileDescriptionTextColor,
                        ),
              ),
            for (final tile in tiles) tileSemanticsNode(tile),
          ],
        ),
      );
    }

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            sectionHeader(
              title: title!,
              padding:
                  titlePadding ??
                  EdgeInsetsDirectional.only(
                    top: textScaler.scale(24),
                    bottom: textScaler.scale(12),
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
            // Card no longer has a margin, so keep untitled sections apart.
            SizedBox(height: textScaler.scale(8)),
          Card(
            // No margin, so the card's left edge lines up with the title.
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 2,
            color: theme.themeData.settingsSectionBackground,
            child: buildTileList(),
          ),
        ],
      ),
    );
  }

  Widget buildTileList() {
    return ListView.separated(
      shrinkWrap: true,
      itemCount: tiles.length,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (BuildContext context, int index) {
        return tiles[index];
      },
      separatorBuilder: (BuildContext context, int index) {
        return Divider(
          height: 0,
          thickness: 1,
          color: SettingsTheme.of(context).themeData.dividerColor,
        );
      },
    );
  }
}
