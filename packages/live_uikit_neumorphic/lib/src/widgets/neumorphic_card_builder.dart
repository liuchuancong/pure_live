import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/styling.dart';

/// Builds a soft Neumorphic card from a [LanguageCardSpec] (§9 Card), honouring
/// the dense padding and wrapping an interactive card in a gesture layer.
abstract final class NeumorphicCardBuilder {
  /// Builds the card for [spec].
  static Widget build(BuildContext context, LanguageCardSpec spec) {
    final theme = LiveTheme.of(context);
    return neu.NeuCard(
      padding: EdgeInsets.all(spec.dense ? theme.card.padding * 0.66 : theme.card.padding),
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
}
