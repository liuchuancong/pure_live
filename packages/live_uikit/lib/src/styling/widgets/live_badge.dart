import 'package:flutter/widgets.dart';
import 'package:live_uikit/src/styling/component_token.dart' show BadgeComponentToken;

import 'package:live_uikit/src/styling/root/live_config_provider.dart';

/// A status badge in the token model — Ant's `Badge`. Overlays a dot or a
/// counted pill on the top-right of [child], or renders standalone when no
/// [child] is given. Colours, size and the pill radius come from
/// [BadgeComponentToken].
class LiveBadge extends StatelessWidget {
  /// A badge.
  const new({
    this.child,
    this.count,
    this.label,
    this.dot = false,
    this.enabled = true,
    this.max = 99,
    this.color,
    super.key,
  });

  /// The widget the badge is anchored to; omit for a standalone badge.
  final Widget? child;

  /// A numeric count; shows `max+` when it exceeds [max]. Null hides the count.
  final int? count;

  /// A text label for the pill (used when [count] is null).
  final String? label;

  /// Whether to render a small dot instead of a pill.
  final bool dot;

  /// Whether the badge is shown at all.
  final bool enabled;

  /// The count ceiling before it collapses to `max+`.
  final int max;

  /// An optional background override (defaults to the error colour).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final bt = theme.badge;
    final background = color ?? bt.background;

    final String? text;
    if (dot) {
      text = null;
    } else if (count case final c?) {
      text = c > max ? '$max+' : '$c';
    } else {
      text = label;
    }

    final pill = dot
        ? Container(
            width: bt.dotSize,
            height: bt.dotSize,
            decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          )
        : Container(
            constraints: BoxConstraints(minWidth: bt.height),
            height: bt.height,
            padding: EdgeInsets.symmetric(horizontal: bt.paddingInline),
            decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(bt.height)),
            alignment: Alignment.center,
            child: Text(
              text ?? '',
              style: theme.text.caption.copyWith(
                color: bt.foreground,
                fontWeight: FontWeight.w500,
                fontSize: bt.fontSize,
              ),
            ),
          );

    if (!enabled || (text == null && !dot)) {
      return child ?? const SizedBox.shrink();
    }
    if (child == null) {
      return pill;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child!,
        Positioned(
          top: -bt.offset,
          right: -bt.offset,
          child: DecoratedBox(
            decoration: BoxDecoration(color: theme.colors.bgContainer, borderRadius: BorderRadius.circular(bt.height)),
            child: pill,
          ),
        ),
      ],
    );
  }
}
