import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/shared/player/on_video_colors.dart';

/// A bar control that names its catalogue's answer: the glyph, the choice
/// in force, and the door's chevron — 画质 · 1080P, 倍速 · 2x. The panel
/// itself hangs where the page mounts it (`PlayerOverlayPanel` under
/// `PlayerPanelHost`); this is only the button that opens it, so a picker
/// keeps whatever hover or press wiring its page already runs.
///
/// Under a window narrower than 480 the value's word folds away and the
/// glyph speaks alone, the way the transport's other controls do.
final class PlayerBarChoice extends StatelessWidget {
  /// Draws the picker button; [anchorKey] is the box its panel measures.
  const PlayerBarChoice({
    required this.anchorKey,
    required this.label,
    required this.value,
    required this.icon,
    required this.onPressed,
    this.selected = false,
    super.key,
  });

  /// The box the page's panel hangs from.
  final GlobalKey anchorKey;

  /// The control's name (screen readers, tooltip).
  final String label;

  /// The choice in force (`1080P 高清`), drawn after the glyph.
  final String value;

  /// The catalogue's glyph.
  final DsIconData icon;

  /// Fired when the picker is asked for.
  final VoidCallback? onPressed;

  /// Draws at full strength while the catalogue stands open.
  final bool selected;

  /// Whether the window's width folds the value's word away.
  static bool compactOf(BuildContext context) => MediaQuery.sizeOf(context).width < 480;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final compact = compactOf(context);
    return DsPressable(
      semanticLabel: '$label $value',
      onPressed: onPressed,
      builder: (context, states, _) {
        final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
        return Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8),
          decoration: BoxDecoration(
            color: selected
                ? OnVideoColors.inkPressed
                : lit
                ? OnVideoColors.inkHover
                : null,
            borderRadius: BorderRadius.circular(theme.radii.control(40)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s4,
            children: [
              DsIcon(icon, size: 16, color: OnVideoColors.foreground),
              if (!compact)
                Text(
                  value,
                  style: theme.typography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: OnVideoColors.foreground,
                  ),
                ),
              const DsIcon(DsIcons.chevronDown, size: 12, color: OnVideoColors.inkMuted),
            ],
          ),
        );
      },
    );
  }
}
