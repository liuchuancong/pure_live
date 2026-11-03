import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/shared/player/player_overlay.dart' show playerInk;

/// The number a volume gesture is setting, shown over the picture.
///
/// A player has no slider under the finger during a drag on the frame, so the
/// gesture answers with this chip instead: the glyph says whether it landed on
/// mute, the figure says where the drag is. It is the one chip every surface
/// uses — the room's drag and wheel, and the media preview's — so a viewer who
/// learned the gesture on one finds the same feedback on the other.
///
/// The caller positions it (a room puts it at its end edge, a preview at the
/// picture's) and fades it away; the chip itself never takes pointer.
final class PlayerVolumeHud extends StatelessWidget {
  /// Shows [value] (0–1) as a percentage.
  const PlayerVolumeHud({required this.value, super.key});

  /// The volume the gesture is at, already clamped to 0–1.
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s16, vertical: DsSpace.s12),
          decoration: DsBoxDecoration(
            color: const Color(0xCC000000),
            borderRadius: BorderRadius.circular(theme.radii.card),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s4,
            children: [
              DsIcon(value <= 0.001 ? DsIcons.volumeX : DsIcons.volume2, size: 24, color: playerInk),
              Text(
                '${(value * 100).round()}%',
                style: theme.typography.numeric(theme.typography.caption.copyWith(color: playerInk)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
