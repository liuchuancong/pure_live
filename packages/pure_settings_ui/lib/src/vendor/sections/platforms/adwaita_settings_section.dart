import 'package:flutter/material.dart';
import 'package:pure_settings_ui/src/vendor/sections/section_header.dart';
import 'package:pure_settings_ui/src/vendor/tiles/abstract_settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/tiles/platforms/adwaita_settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_semantics.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';

// A group of a GNOME preferences page (`AdwPreferencesGroup` holding a
// `.boxed-list`, libadwaita 1.10). All sizes are in logical pixels.

/// Space between groups (`AdwPreferencesPage` box `border-spacing`).
const double kAdwaitaGroupSpacing = 24;

/// Side margins of the page content, inside the clamp.
const double kAdwaitaPageSideMargin = 12;

/// Space above the first group.
const double kAdwaitaPageTopMargin = 24;

/// The group title row is at least 34 tall, then 6 above the card.
const double _kTitleMinHeight = 34;
const double _kTitleGap = 6;

/// The width `AdwClamp` gives its child when it has [width] to fill.
///
/// Up to [tighteningThreshold] the child gets all of it. From there the
/// child grows more and more slowly (ease-out-cubic) until it reaches
/// [maximumSize], at `threshold + 3 * (maximum - threshold)`, and stays
/// there. With the preferences page values (600 and 400), a 1000 px wide
/// window or wider gives a 600 px column.
double adwaitaClampWidth(
  double width, {
  double maximumSize = 600,
  double tighteningThreshold = 400,
}) {
  final lower = tighteningThreshold < maximumSize
      ? tighteningThreshold
      : maximumSize;
  // ADW_EASE_OUT_TAN_CUBIC: the slope of ease-out-cubic at 0.
  final upper = lower + 3 * (maximumSize - lower);
  if (width <= lower) return width;
  if (width >= upper) return maximumSize;
  // ADW_EASE_OUT_CUBIC is 1 - (1 - t)^3.
  final rest = 1 - (width - lower) / (upper - lower);
  return lower + (maximumSize - lower) * (1 - rest * rest * rest);
}

class AdwaitaSettingsSection extends StatelessWidget {
  const AdwaitaSettingsSection({
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
    final theme = SettingsTheme.of(context).themeData;

    return Padding(
      // The list adds 24 above the first group; each group keeps 24 below.
      padding:
          margin ??
          const EdgeInsetsDirectional.only(
            start: kAdwaitaPageSideMargin,
            end: kAdwaitaPageSideMargin,
            bottom: kAdwaitaGroupSpacing,
          ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding:
                  titlePadding ??
                  const EdgeInsetsDirectional.only(bottom: _kTitleGap),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _kTitleMinHeight),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: sectionTitle(
                    title!,
                    style: (theme.titleTextStyle ?? kAdwaitaHeadingStyle)
                        .copyWith(color: theme.titleTextColor),
                  ),
                ),
              ),
            ),
          AdwaitaBoxedList(tiles: tiles),
        ],
      ),
    );
  }
}

/// A `.boxed-list`: the rows on one card with 12 px corners and a soft
/// shadow, separated by full-width 1 px lines.
class AdwaitaBoxedList extends StatelessWidget {
  const AdwaitaBoxedList({required this.tiles, super.key});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final theme = SettingsTheme.of(context).themeData;
    final divider = theme.dividerColor ?? const Color.fromRGBO(0, 0, 6, 0.07);

    return CustomPaint(
      painter: const _AdwaitaCardShadowPainter(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kAdwaitaCardRadius),
        child: ColoredBox(
          color: theme.settingsSectionBackground ?? const Color(0x00000000),
          // Lets Material widgets (ListTile, Checkbox...) in custom rows work
          // without a Scaffold, and gives custom rows the row text style.
          child: Material(
            type: MaterialType.transparency,
            child: DefaultTextStyle(
              style: kAdwaitaBodyStyle.copyWith(
                color: theme.settingsTileTextColor,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < tiles.length; i++) ...[
                    AdwaitaSettingsTileAdditionalInfo(
                      isFirst: i == 0,
                      isLast: i == tiles.length - 1,
                      child: tileSemanticsNode(tiles[i]),
                    ),
                    if (i != tiles.length - 1)
                      SizedBox(height: 1, child: ColoredBox(color: divider)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The libadwaita card shadow, in both light and dark mode:
///
/// ```css
/// box-shadow: 0 0 0 1px rgb(0 0 6 / 3%),
///             0 1px 3px 1px rgb(0 0 6 / 7%),
///             0 2px 6px 2px rgb(0 0 6 / 3%);
/// ```
///
/// Like a CSS box shadow, it is only painted outside the card, so a
/// translucent card (dark mode) does not show it through.
class _AdwaitaCardShadowPainter extends CustomPainter {
  const _AdwaitaCardShadowPainter();

  /// (y offset, blur radius, spread, alpha)
  static const List<(double, double, double, double)> _shadows = [
    (0, 0, 1, 0.03),
    (1, 3, 1, 0.07),
    (2, 6, 2, 0.03),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final RRect card = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(kAdwaitaCardRadius),
    );
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect((Offset.zero & size).inflate(24))
        ..addRRect(card),
    );
    for (final (dy, blur, spread, alpha) in _shadows) {
      final Paint paint = Paint()..color = Color.fromRGBO(0, 0, 6, alpha);
      // A CSS blur radius is two standard deviations.
      if (blur > 0) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2);
      }
      canvas.drawRRect(card.inflate(spread).shift(Offset(0, dy)), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AdwaitaCardShadowPainter oldDelegate) => false;
}
