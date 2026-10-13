import 'package:flutter/widgets.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/styling.dart';

/// Builds a frosted glass card from a [LanguageCardSpec] (§9 Card). A non-tap
/// card is a plain [glass.GlassCard]; an interactive one wraps the content in an
/// opaque gesture layer so click/long-press behavior is preserved.
abstract final class GlassCardBuilder {
  /// Builds the card for [spec].
  static Widget build(BuildContext context, LanguageCardSpec spec) => glass.GlassCard(
    child: spec.onTap == null
        ? spec.child
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: spec.onTap,
            onLongPress: spec.onLongPress,
            child: spec.child,
          ),
  );
}
