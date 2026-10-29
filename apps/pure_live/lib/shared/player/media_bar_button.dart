import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/shared/focus/tv_focus_scale.dart';

/// A compact icon control that floats over the picture: a square hit target,
/// a light fill under the pointer, the glyph muted until [selected], and the
/// label screen readers announce.
///
/// The room's control bar, the IPTV strip and the floating player all use
/// this one control, so the transport and the verbs read alike wherever they
/// appear.
final class MediaBarButton extends StatelessWidget {
  /// The control showing [icon].
  const MediaBarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.onDark = true,
    this.autofocus = false,
    this.tooltip = true,
    this.zoomsOnTv = true,
    this.size,
    this.iconSize,
    this.focusNode,
    super.key,
  });

  /// The glyph.
  final DsIconData icon;

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
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          width: side,
          height: side,
          decoration: DsBoxDecoration(
            color: hovered && enabled ? (onDark ? const Color(0x24FFFFFF) : colors.hover) : null,
            borderRadius: theme.radii.controlCorners(null, side),
          ),
          child: Center(
            child: DsIcon(
              icon,
              size: iconSize ?? theme.sizes.iconSm,
              color: onDark
                  ? !enabled
                        ? const Color(0x66FFFFFF)
                        : selected
                        ? const Color(0xFFFFFFFF)
                        : const Color(0xCCFFFFFF)
                  : !enabled
                  ? colors.textSubtle
                  : selected
                  ? colors.text
                  : colors.textMuted,
            ),
          ),
        );
      },
    );
    final named = tooltip ? DsTooltip(message: label, child: button) : button;
    return zoomsOnTv ? TvFocusScale(child: named) : named;
  }
}
