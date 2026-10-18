import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_metrics.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_tile.dart';
import 'package:pure_settings_ui/src/pure/settings_language.dart';
import 'package:pure_settings_ui/src/vendor/sections/section_header.dart';
import 'package:pure_settings_ui/src/vendor/tiles/abstract_settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// A group of the pure style: a title over one card holding every tile, which
/// is the shape the iOS, macOS, web and GNOME styles share and the one
/// pure_uikit's own [PureCard] is built for.
///
/// The card is [PureCard], so it is forui's `FCard`, glass's frosted
/// `GlassCard`, a neumorphic embossed plane or a wind container according to
/// the active language, and the rows inside are [PureSettingsTile]s drawing
/// that language's real row. The section states each row's divider through a
/// [PureSettingsRowScope], because a row cannot know whether it is the last.
///
/// The side gutters are the list's own padding, not the section's margin — see
/// `SettingsList.calculateDefaultPadding` for the `pure` case — so the default
/// margin only spaces one section from the next.
class PureSettingsSection extends StatelessWidget {
  /// A section of [tiles] under [title].
  const new({required this.tiles, required this.margin, required this.title, this.titlePadding, super.key});

  /// The rows, top to bottom. Never empty: `SettingsSection` renders nothing
  /// at all for a section with no tiles.
  final List<AbstractSettingsTile> tiles;

  /// Replaces the default spacing from the section above.
  final EdgeInsetsDirectional? margin;

  /// The group's heading, usually a [Text] in sentence case.
  final Widget? title;

  /// Replaces the default padding around [title].
  final EdgeInsetsGeometry? titlePadding;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsTheme.of(context).themeData;
    final theme = PureTheme.of(context);
    final heading = title;
    final last = tiles.length - 1;
    final style = pureSettingsStyle(context);

    return Padding(
      padding: margin ?? const EdgeInsetsDirectional.only(bottom: pureSettingsSectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (heading != null)
            sectionHeader(
              title: heading,
              padding:
                  titlePadding ?? const EdgeInsetsDirectional.only(start: PureSpacing.sm, bottom: pureSettingsTitleGap),
              style: (settings.titleTextStyle ?? theme.text.caption).copyWith(color: settings.titleTextColor),
            ),
          PureCard(
            padding: style.cardPadding,
            bordered: style.cardBordered,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < tiles.length; index++)
                  PureSettingsRowScope(divided: style.rowDividers && index < last, child: tiles[index]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
