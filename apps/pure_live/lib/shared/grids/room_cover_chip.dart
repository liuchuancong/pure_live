import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_live/shared/player/on_video_colors.dart';

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
          padding: EdgeInsets.symmetric(
            horizontal: compact ? DsSpace.s5 : DsSpace.s8,
            vertical: compact ? DsSpace.s3 : DsSpace.s4,
          ),
          background: OnVideoColors.coverMark,
          foreground: OnVideoColors.foreground,
          textStyle: style ?? theme.typography.caption,
          iconSize: compact ? theme.sizes.iconXs : theme.sizes.iconSm,
          gap: compact ? DsSpace.s3 : DsSpace.s4,
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
  colors: [OnVideoColors.coverMark, OnVideoColors.clear],
);
