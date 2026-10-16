import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a Material UI card from a [LanguageCardSpec] (§9 Card): surface,
/// selection tint, optional border and an ink-well so taps ripple. Preserves
/// padding, density, the inline style override and click behaviour from the spec.
abstract final class MaterialCardBuilder {
  /// Builds the card for [spec].
  static Widget build(BuildContext context, LanguageCardSpec spec) {
    final theme = LiveTheme.of(context);
    final interactive = spec.onTap != null || spec.onLongPress != null;
    final override = spec.style;
    // An inline `style` wins over the theme, the same precedence the token
    // renderer gives it. Only the properties a Material card can express are
    // read — fill, radius and border — and the rest stay library defaults
    // (§8.1 "map only supported") rather than being hand-painted on top.
    final radius = override?.borderRadius ?? mu.BorderRadius.circular(theme.card.borderRadius);
    final borderColor = override?.borderColor ?? (spec.bordered ? theme.colors.border : null);
    return mu.Card(
      clipBehavior: Clip.antiAlias,
      color: override?.background ?? (spec.selected ? theme.colors.primaryBg : null),
      shape: mu.RoundedRectangleBorder(
        side: borderColor == null
            ? mu.BorderSide.none
            : mu.BorderSide(color: borderColor, width: override?.borderWidth ?? 1),
        borderRadius: radius,
      ),
      child: mu.InkWell(
        onTap: spec.onTap,
        onLongPress: spec.onLongPress,
        // Focus belongs to an interactive card; a plain one must not take it.
        focusNode: interactive ? spec.focusNode : null,
        autofocus: interactive && spec.autofocus,
        child: Padding(
          padding: spec.padding ?? EdgeInsets.all(spec.dense ? theme.card.padding * 0.66 : theme.card.padding),
          child: spec.child,
        ),
      ),
    );
  }
}
