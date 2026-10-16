import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Wind card from a [LanguageCardSpec] (§9 Card).
///
/// `WCard` is the fork's card *structure* — a `w-full flex flex-col` container
/// with header/body/footer slots rendered through `WDiv` — and nothing more: it
/// paints no surface, and a `className` replaces its default classes rather than
/// adding to them. So the builder keeps WCard for the structure and takes the
/// surface from the resolved token, which is the same source every other path in
/// this package paints from (§8.1). Selection tints the surface, `bordered` or a
/// focused selection draws the token border, `dense` tightens the padding, and a
/// gesture layer appears only when the caller supplied a tap.
abstract final class WindCardBuilder {
  /// Builds the card for [spec].
  static Widget build(BuildContext context, LanguageCardSpec spec) {
    final theme = LiveTheme.of(context);
    final interactive = spec.onTap != null || spec.onLongPress != null;
    final override = spec.style;
    Widget body = Padding(
      padding: spec.padding ?? EdgeInsets.all(spec.dense ? theme.card.padding * 0.66 : theme.card.padding),
      child: spec.child,
    );
    if (interactive) {
      body = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: spec.onTap,
        onLongPress: spec.onLongPress,
        child: body,
      );
    }
    // `WCard`'s flex column sizes its body to the content, so an interactive
    // card would otherwise be tappable only behind its own text while the surface
    // paints full width. Stretching the body makes the hit area match the card.
    body = SizedBox(width: double.infinity, child: body);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: override?.background ?? (spec.selected ? theme.colors.primaryBg : theme.card.background),
        borderRadius: override?.borderRadius ?? BorderRadius.circular(theme.card.borderRadius),
        border: spec.bordered || spec.selected ? Border.all(color: theme.colors.border) : null,
      ),
      child: wind.WCard(child: body),
    );
  }
}
