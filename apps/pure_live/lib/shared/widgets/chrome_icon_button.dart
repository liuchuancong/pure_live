import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

/// A flat square icon action for the app's own chrome — the title bar's
/// strip and the phone's top bar. Hover lightens the tile, pressing
/// darkens it, a danger action fills red under the pointer, and a disabled
/// one dims its ink and drops the press.
///
/// The tooltip is opt-in: the window's caption arrows are named by a
/// tooltip in their caller, an action that already sits under a label
/// needs none.
final class ChromeIconButton extends StatelessWidget {
  /// A button showing [icon], named [semanticLabel] for screen readers.
  const ChromeIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.tooltip,
    this.shortcut,
    this.tooltipSide = DsSide.bottom,
    this.size = 44,
    this.iconSize = 16,
    this.enabled = true,
    this.danger = false,
    super.key,
  });

  /// The glyph.
  final DsIconData icon;

  /// The name screen readers announce.
  final String semanticLabel;

  /// Fired on press; null leaves the tile inert.
  final VoidCallback? onPressed;

  /// The hover/focus tooltip; null draws no tooltip (the caller may wrap
  /// the button in its own, e.g. to reach a different side).
  final String? tooltip;

  /// The keys the tooltip shows beside [tooltip], e.g. "Ctrl K".
  final String? shortcut;

  /// The side the tooltip opens to.
  final DsSide tooltipSide;

  /// The square's side: the title bar's 44, a touch bar's 48.
  final double size;

  /// The glyph's side: a caption's 16, a touch bar's 20.
  final double iconSize;

  /// False dims the icon and deadens the press.
  final bool enabled;

  /// Paints a red fill under the pointer: close, delete, stop.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final button = SizedBox(
      width: size,
      height: size,
      child: DsPressable(
        semanticLabel: semanticLabel,
        onPressed: enabled ? onPressed : null,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          final pressed = states.contains(WidgetState.pressed);
          Color? background;
          if (enabled) {
            if (danger && hovered) {
              background = colors.danger.fill;
            } else if (hovered || pressed) {
              background = pressed ? colors.press : colors.hover;
            }
          }
          return ColoredBox(
            color: background ?? const Color(0x00000000),
            child: Center(child: DsIcon(icon, size: iconSize, color: enabled ? colors.text : colors.textSubtle)),
          );
        },
      ),
    );
    final message = tooltip;
    if (message == null) return button;
    return DsTooltip(message: message, shortcut: shortcut, side: tooltipSide, child: button);
  }
}
