import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/l10n/translations.dart';

/// The heart beside an area: filled in the accent while followed, hollow
/// while not. Pressing it follows or unfollows.
///
/// This is only the mark; the page that knows the follow state wraps it in a
/// [DsTooltip] or a row of its own.
final class AreaFollowButton extends StatelessWidget {
  /// The heart for [followed].
  const AreaFollowButton({required this.followed, required this.onPressed, super.key});

  /// Whether the area is followed.
  final bool followed;

  /// Follows or unfollows the area.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    return DsPressable(
      semanticLabel: followed ? t.areas.unfollow : t.areas.follow,
      onPressed: onPressed,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return DsIcon(
          DsIcons.heart,
          size: theme.sizes.iconSm,
          color: followed
              ? hovered
                    ? colors.danger.fill
                    : colors.accent
              : hovered
              ? colors.accent
              : colors.textSubtle,
        );
      },
    );
  }
}
