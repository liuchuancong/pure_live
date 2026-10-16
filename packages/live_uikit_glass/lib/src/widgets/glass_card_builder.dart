import 'package:flutter/widgets.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/live_uikit.dart';

/// Builds a frosted card from a [LanguageCardSpec] (§9 Card).
///
/// `GlassCard` owns the surface, radius and blur, so the adapter leaves them at
/// the library's defaults and passes through what the spec adds: the padding (with
/// the `dense` step tightening it the same way the token renderer does), and a
/// gesture layer only when the caller supplied a tap. `selected` and `bordered`
/// have no frosted equivalent — the card is translucent by definition — so they
/// are recorded as unmappable here (§15) rather than faked with an opaque border
/// that would defeat the whole style.
abstract final class GlassCardBuilder {
  /// Builds the card for [spec].
  static Widget build(BuildContext context, LanguageCardSpec spec) {
    final theme = LiveTheme.of(context);
    final body = spec.onTap == null
        ? spec.child
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: spec.onTap,
            onLongPress: spec.onLongPress,
            child: spec.child,
          );
    return glass.GlassCard(
      padding: spec.padding ?? EdgeInsets.all(spec.dense ? theme.card.padding * 0.66 : theme.card.padding),
      child: body,
    );
  }
}
