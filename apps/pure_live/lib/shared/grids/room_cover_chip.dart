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
    this.compact = false,
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

  /// The tighter shape a small thumbnail carries: less padding, a smaller
  /// glyph and caption-size words.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DsBadge(
        label: Text(text),
        dot: false,
        icon: icon == null ? null : DsIcon(icon!),
        style: DsBadgeStyle(
          padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 8, vertical: compact ? 2 : 4),
          background: const Color(0x8C000000),
          foreground: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(compact ? 5 : 6),
          textStyle: style ?? theme.typography.caption.copyWith(fontSize: compact ? 10 : null),
          iconSize: compact ? 10 : 12,
          gap: compact ? 3 : 4,
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
