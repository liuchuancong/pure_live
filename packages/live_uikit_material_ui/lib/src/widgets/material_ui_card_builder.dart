import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a Material UI card from a [LanguageCardSpec] (§9 Card): surface,
/// selection tint, optional border and an ink-well so taps ripple. Preserves
/// padding, semantics and click behaviour from the spec.
abstract final class MaterialUiCardBuilder {
  /// Builds the card for [spec].
  static Widget build(BuildContext context, LanguageCardSpec spec) {
    final theme = LiveTheme.of(context);
    return mu.Card(
      clipBehavior: Clip.antiAlias,
      color: spec.selected ? theme.colors.primaryBg : null,
      shape: spec.bordered
          ? mu.RoundedRectangleBorder(
              side: mu.BorderSide(color: theme.colors.border),
              borderRadius: mu.BorderRadius.circular(theme.card.borderRadius),
            )
          : null,
      child: mu.InkWell(
        onTap: spec.onTap,
        onLongPress: spec.onLongPress,
        child: Padding(padding: spec.padding ?? EdgeInsets.all(theme.card.padding), child: spec.child),
      ),
    );
  }
}
