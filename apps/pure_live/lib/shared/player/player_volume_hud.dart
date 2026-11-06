import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/shared/player/on_video_colors.dart';

/// The number a picture gesture is setting, shown over the frame.
///
/// A player has no slider under the finger during a drag on the picture, so the
/// gesture answers with this chip instead: the glyph says which figure it is
/// (the volume, or the screen brightness the left half of the picture adjusts),
/// the number says where the drag has reached. It is the one chip every surface
/// uses — the room's drags and wheel, the IPTV page, the vod and hongguo
/// players, and the media preview — so a viewer who learned the gesture on one
/// finds the same feedback on the other.
///
/// The caller positions it (a room puts it at its end edge, a preview at the
/// picture's) and fades it away; the chip itself never takes pointer.
final class PlayerVolumeHud extends StatelessWidget {
  /// Shows [value] (0–1) as a percentage, under [icon]'s meaning.
  const PlayerVolumeHud({required this.value, this.icon, super.key});

  /// The volume the gesture is at, already clamped to 0–1.
  final double value;

  /// The glyph that names the figure: null draws the speaker, i.e. a volume.
  final DsIconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s16, vertical: DsSpace.s12),
          decoration: DsBoxDecoration(
            color: OnVideoColors.scrimDeep,
            borderRadius: BorderRadius.circular(theme.radii.card),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s4,
            children: [
              DsIcon(icon ?? (value <= 0.001 ? DsIcons.volumeX : DsIcons.volume2), size: 24, color: OnVideoColors.foreground),
              Text(
                '${(value * 100).round()}%',
                style: theme.typography.numeric(theme.typography.caption.copyWith(color: OnVideoColors.foreground)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
