import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/live_uikit.dart';

/// Builds a soft Neumorphic card from a [LanguageCardSpec] (§9 Card).
///
/// **Mapped.** `NeuCard` is the library's own card, and the embossed surface is the
/// card's whole identity: the token padding, the `dense` step, an explicit
/// `padding` override, and a gesture layer only when the caller supplied a tap
/// or a long press — `NeuCard` takes no callbacks itself.
///
/// `selected` and `bordered` have no soft-surface equivalent — a Neumorphic card
/// is defined by its shadow, not a border or fill — so they are left to the
/// library's own pressed state rather than faked with an outline (§15).
abstract final class NeumorphicCardBuilder {
  /// Builds the card for [spec].
  static Widget build(BuildContext context, LanguageCardSpec spec) {
    final theme = LiveTheme.of(context);
    // A card is interactive on either gesture: an `onLongPress`-only caller
    // must not have its callback dropped because only `onTap` was checked (§9).
    final interactive = spec.onTap != null || spec.onLongPress != null;
    return neu.NeuCard(
      padding: spec.padding ?? EdgeInsets.all(spec.dense ? theme.card.padding * 0.66 : theme.card.padding),
      child: !interactive
          ? spec.child
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: spec.onTap,
              onLongPress: spec.onLongPress,
              child: spec.child,
            ),
    );
  }
}
