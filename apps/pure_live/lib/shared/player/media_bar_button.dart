import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:pure_live/shared/focus/tv_focus_scale.dart';
import 'package:pure_live/shared/player/player_overlay.dart' show playerInk;

/// A compact icon control that floats over the picture: a square hit target,
/// a light fill under the pointer, the glyph muted until [selected], and the
/// label screen readers announce.
///
/// The room's control bar, the IPTV strip and the floating player all use
/// this one control, so the transport and the verbs read alike wherever they
/// appear.
final class MediaBarButton extends StatelessWidget {
  /// The control showing [icon], or the bundled svg glyph at [iconAsset].
  const MediaBarButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconAsset,
    this.selected = false,
    this.onDark = true,
    this.autofocus = false,
    this.tooltip = true,
    this.zoomsOnTv = true,
    this.focusRing = false,
    this.size,
    this.iconSize,
    this.focusNode,
    super.key,
  }) : assert((icon == null) != (iconAsset == null), 'give exactly one glyph source: icon or iconAsset');

  /// The glyph.
  final DsIconData? icon;

  /// A bundled svg glyph drawn instead of [icon], tinted with the state
  /// color like a stroke glyph.
  final String? iconAsset;

  /// The name screen readers announce, and the tooltip's words.
  final String label;

  /// Fired on press; null dims the glyph and drops the press.
  final VoidCallback? onPressed;

  /// Draws the glyph at full strength: a control that is on.
  final bool selected;

  /// Draws for the ink over a picture instead of the app's own surface.
  final bool onDark;

  /// Takes the focus when first built (the TV room's first control).
  final bool autofocus;

  /// Shows [label] in a tooltip; off for a touch strip that has no pointer.
  final bool tooltip;

  /// Grows while focused on a TV, like the cards and menu rows do.
  final bool zoomsOnTv;

  /// Draws an on-video focus ring while focused (a TV bar): a remote has no
  /// pointer, so the brightened fill alone does not say where the focus is.
  final bool focusRing;

  /// The square's side; the theme's small size when null.
  final double? size;

  /// The glyph's side; the theme's small icon when null.
  final double? iconSize;

  /// The node the host owns, e.g. a page that puts the focus back on play
  /// when it returns from fullscreen.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final enabled = onPressed != null;
    final side = size ?? theme.sizes.sm;
    final button = DsPressable(
      semanticLabel: label,
      onPressed: onPressed,
      autofocus: autofocus,
      focusNode: focusNode,
      builder: (context, states, _) {
        // Focus lights the button like hover does: a remote or keyboard
        // user sees where they are even where a zoom is not drawn. A TV bar
        // also draws the ring, because the fill alone is faint from a sofa.
        final focused = states.contains(WidgetState.focused);
        final lit = states.contains(WidgetState.hovered) || focused;
        final corners = theme.radii.controlCorners(null, side);
        final glyphSide = iconSize ?? theme.sizes.iconSm;
        final glyphColor = onDark
            ? !enabled
                  ? const Color(0x66FFFFFF)
                  : selected
                  ? playerInk
                  : const Color(0xCCFFFFFF)
            : !enabled
            ? colors.textSubtle
            : selected
            ? colors.text
            : colors.textMuted;
        return Container(
          width: side,
          height: side,
          decoration: DsBoxDecoration(
            color: lit && enabled ? (onDark ? const Color(0x24FFFFFF) : colors.hover) : null,
            borderRadius: corners,
          ),
          foregroundDecoration: focusRing && focused && enabled
              ? BoxDecoration(
                  border: Border.all(color: playerInk, width: 2),
                  borderRadius: corners,
                )
              : null,
          child: Center(
            child: switch (iconAsset) {
              final String asset => SvgPicture.asset(
                asset,
                width: glyphSide,
                height: glyphSide,
                colorFilter: ColorFilter.mode(glyphColor, BlendMode.srcIn),
              ),
              _ => DsIcon(icon!, size: glyphSide, color: glyphColor),
            },
          ),
        );
      },
    );
    final named = tooltip ? DsTooltip(message: label, child: button) : button;
    return zoomsOnTv ? TvFocusScale(child: named) : named;
  }
}
