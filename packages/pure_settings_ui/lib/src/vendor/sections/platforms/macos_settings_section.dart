import 'package:flutter/material.dart';
import 'package:pure_settings_ui/src/vendor/sections/abstract_settings_section.dart';
import 'package:pure_settings_ui/src/vendor/sections/section_header.dart';
import 'package:pure_settings_ui/src/vendor/sections/settings_section.dart';
import 'package:pure_settings_ui/src/vendor/tiles/abstract_settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/tiles/platforms/macos_settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/tiles/settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_semantics.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';

/// A group of a macOS 26/27 System Settings grouped form.
///
/// The header sits above the card in 13pt semibold, 10pt in from the card
/// edge.
/// The tiles share a card with 12pt continuous corners and no border or
/// shadow, split by 1pt separators inset 10pt from both card edges. A tile's
/// `description` becomes 11pt grey text under the card, and the tiles after
/// it start a new card, as SwiftUI does for a section footer.
///
/// Spacing, as measured in System Settings: cards sit 20pt from the sides of
/// the list, 10pt apart, and a header's line starts 30pt below the card
/// above it. After a footer, the next card or header starts 30pt below it.
/// [SettingsList] tells a section whether the section before it ended with
/// a footer through [MacosSectionContext].
class MacosSettingsSection extends StatelessWidget {
  const MacosSettingsSection({
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

  /// Space above a header: with the previous section's 10pt bottom margin,
  /// the header line starts 30pt below the card or footer above it. At the
  /// top of the list it starts 20pt down. An untitled section after a footer
  /// gets the same space.
  static const double headerTopGap = 20;

  /// Space between a header's 16pt line and the card.
  static const double headerBottomGap = 10;

  /// Space between two cards.
  static const double cardGap = 10;

  /// Side margins of the cards.
  static const double sideMargin = 20;

  @override
  Widget build(BuildContext context) {
    final theme = SettingsTheme.of(context).themeData;
    final textScaler = MediaQuery.textScalerOf(context);

    final children = <Widget>[];
    if (title != null) {
      final style = theme.titleTextStyle ?? kMacosHeaderStyle;
      children.add(
        sectionHeader(
          title: title!,
          padding:
              titlePadding ??
              EdgeInsetsDirectional.only(
                start: kMacosRowInset,
                end: kMacosRowInset,
                bottom: textScaler.scale(headerBottomGap),
              ),
          style: style.copyWith(color: style.color ?? theme.titleTextColor),
        ),
      );
    }

    // A tile with a description ends its card: the description goes under
    // the card and the next tile starts a new one.
    var cardStart = 0;
    for (var i = 0; i < tiles.length; i++) {
      final tile = tiles[i];
      final description = tile is SettingsTile ? tile.description : null;
      final isLastTile = i == tiles.length - 1;
      if (description == null && !isLastTile) continue;

      children.add(
        _MacosCard(theme: theme, tiles: tiles.sublist(cardStart, i + 1)),
      );
      if (description != null) {
        children.add(
          buildMacosFooter(
            context: context,
            description: description,
            padding: (tile as SettingsTile).descriptionPadding,
            isLast: isLastTile,
          ),
        );
      }
      cardStart = i + 1;
    }

    return Padding(
      padding:
          margin ??
          EdgeInsetsDirectional.only(
            start: sideMargin,
            end: sideMargin,
            top: title != null || MacosSectionContext.followsFooterOf(context)
                ? textScaler.scale(headerTopGap)
                : 0,
            bottom: textScaler.scale(cardGap),
          ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Whether [section] ends with a footer: its last tile has a `description`.
bool macosSectionEndsWithFooter(AbstractSettingsSection section) {
  if (section is! SettingsSection || section.tiles.isEmpty) return false;
  final last = section.tiles.last;
  return last is SettingsTile && last.description != null;
}

/// Tells a [MacosSettingsSection] whether the section shown before it ended
/// with a footer, so it can keep the 30pt System Settings leaves after one.
class MacosSectionContext extends InheritedWidget {
  const MacosSectionContext({
    super.key,
    required this.followsFooter,
    required super.child,
  });

  /// The section before this one ends with a footer.
  final bool followsFooter;

  static bool followsFooterOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<MacosSectionContext>()
          ?.followsFooter ??
      false;

  @override
  bool updateShouldNotify(MacosSectionContext oldWidget) =>
      followsFooter != oldWidget.followsFooter;
}

/// One card: the tiles on the card color, with separators between them.
class _MacosCard extends StatelessWidget {
  const _MacosCard({required this.theme, required this.tiles});

  final SettingsThemeData theme;
  final List<AbstractSettingsTile> tiles;

  @override
  Widget build(BuildContext context) {
    final separator = Padding(
      padding: const EdgeInsets.symmetric(horizontal: kMacosRowInset),
      child: SizedBox(
        height: 1,
        child: ColoredBox(color: theme.dividerColor ?? const Color(0x00000000)),
      ),
    );

    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(kMacosCardRadius),
      child: ColoredBox(
        color: theme.settingsSectionBackground ?? const Color(0x00000000),
        // Lets Material widgets (InkWell, IconButton...) in custom tiles
        // work without a Scaffold, and gives custom tiles the row text style.
        child: Material(
          type: MaterialType.transparency,
          child: DefaultTextStyle(
            style: kMacosBodyStyle.copyWith(color: theme.settingsTileTextColor),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) separator,
                  MacosSettingsTileScope(
                    isFirst: i == 0,
                    isLast: i == tiles.length - 1,
                    child: tileSemanticsNode(tiles[i]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
