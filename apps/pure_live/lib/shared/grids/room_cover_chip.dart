import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

/// A small translucent capsule laid over a room's cover: the title, the
/// audience figure, a platform mark. Dark enough to read on bright and dark
/// covers alike; the words ellipsize inside [maxWidth].
final class RoomCoverChip extends StatelessWidget {
  /// A chip over [text], optionally led by [icon].
  const RoomCoverChip({
    required this.text,
    this.icon,
    this.maxWidth = 200,
    this.style,
    super.key,
  });

  /// The words shown.
  final String text;

  /// A leading glyph, e.g. the audience flame.
  final DsIconData? icon;

  /// The widest the capsule may get before the words ellipsize.
  final double maxWidth;

  /// Overrides the default small white-on-black type.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x8C000000),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            if (icon != null) DsIcon(icon!, size: 12, color: const Color(0xFFFFFFFF)),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style ?? theme.typography.caption.copyWith(color: const Color(0xFFFFFFFF)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The soft dark band under a cover's bottom edge, so white chips stay
/// legible over a bright picture.
const LinearGradient kRoomCoverScrim = LinearGradient(
  begin: AlignmentDirectional.bottomCenter,
  end: AlignmentDirectional.topCenter,
  colors: [Color(0x8C000000), Color(0x00000000)],
);
