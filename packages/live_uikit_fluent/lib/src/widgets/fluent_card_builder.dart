import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';

/// Builds a Fluent card from a [LanguageCardSpec] (§9 Card): the fork's card
/// surface with the token padding, the `dense` step, an explicit `padding`
/// override, and `selected`/`bordered` mapped onto Fluent's own background and
/// border colours rather than an approximation. `focusNode`/`autofocus` have no
/// slot on `fluent.Card` — it is a surface, not a control — so the interactive
/// variant keeps the pointer affordance and documents the gap (§9/§15).
abstract final class FluentCardBuilder {
  /// Builds the card for [spec].
  static Widget build(BuildContext context, LanguageCardSpec spec) {
    final theme = LiveTheme.of(context);
    final override = spec.style;
    final interactive = spec.onTap != null || spec.onLongPress != null;
    return fluent.Card(
      padding: spec.padding ?? EdgeInsets.all(spec.dense ? theme.card.padding * 0.66 : theme.card.padding),
      margin: EdgeInsets.zero,
      backgroundColor: override?.background ?? (spec.selected ? theme.colors.primaryBg : null),
      borderColor: spec.bordered || spec.selected || override?.borderColor != null
          ? override?.borderColor ?? theme.colors.border
          : null,
      child: interactive
          ? MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: spec.onTap,
                onLongPress: spec.onLongPress,
                child: spec.child,
              ),
            )
          : spec.child,
    );
  }
}
