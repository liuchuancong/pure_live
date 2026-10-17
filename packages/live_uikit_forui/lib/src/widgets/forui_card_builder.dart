import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/live_uikit.dart';

/// Renders a [LanguageCardSpec] with `FCard` (§9 Card).
abstract final class ForuiCardBuilder {
  /// Builds the card for [spec].
  static Widget build(BuildContext context, LanguageCardSpec spec) {
    final theme = LiveTheme.of(context);
    final card = forui.FCard(
      // `FCard` paints the surface and none of the inside space, so the token padding
      // (or the caller's explicit one) wraps the content here — `dense` is the same
      // 0.66 step the rest of the family takes (§9).
      child: Padding(
        padding: spec.padding ?? EdgeInsets.all(spec.dense ? theme.card.padding * 0.66 : theme.card.padding),
        child: spec.child,
      ),
    );

    final interactive = spec.onTap != null || spec.onLongPress != null;
    if (!interactive) {
      return card;
    }
    // `FCard` is a surface, not a tappable: forui composes interaction with `FTappable`
    // around a card, so the gestures are attached outside the surface rather than by
    // rebuilding the decoration by hand.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: spec.onTap,
      onLongPress: spec.onLongPress,
      child: card,
    );
  }
}
