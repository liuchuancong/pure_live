import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds a native Fluent button from a [LanguageButtonSpec] (§9 Button).
///
/// Primary and danger map to `FilledButton`, secondary/ghost to `Button`; the
/// loading button behaves identically across every style. Business actions stay
/// in the spec's `onPressed` — never here.
///
/// Two spec fields are deliberately not mapped: `selected` and `style`. Both
/// would mean painting over a surface the library's own button owns, and a
/// hand-painted overlay is exactly what §9 rules out.
abstract final class FluentButtonBuilder {
  /// Builds the button for [spec], drawn from this library's own widgets part for part.
  static Widget build(BuildContext context, LanguageButtonSpec spec) {
    final theme = LiveTheme.of(context);
    final onPressed = spec.enabled && !spec.loading && spec.onPressed != null ? spec.onPressed : null;
    final child = _label(spec, theme, foreground: spec.variant == ButtonVariant.ghost ? theme.colors.primary : null);
    final filled = spec.variant == ButtonVariant.primary || spec.variant == ButtonVariant.danger;
    Widget button = filled
        ? fluent.FilledButton(onPressed: onPressed, focusNode: spec.focusNode, autofocus: spec.autofocus, child: child)
        : fluent.Button(onPressed: onPressed, focusNode: spec.focusNode, autofocus: spec.autofocus, child: child);
    if (spec.expand) {
      button = SizedBox(width: double.infinity, child: button);
    }
    final hint = spec.tooltip;
    if (hint != null) {
      // `TooltipButton` is Fluent's own hint affordance and only exists on
      // `Button`, so the core's language-neutral `LiveTooltip` wraps either class
      // identically rather than dropping the filled variant to get it (§9).
      button = LiveTooltip(message: hint, child: button);
    }
    return button;
  }

  /// The button's content, built from this library's own parts: the label, an
  /// optional leading glyph, a spinner while loading, and the bare glyph of an
  /// icon-only button, whose empty label is never painted. The loading state is
  /// the library's own `ProgressRing`, and the glyph size is the theme's label
  /// step, so a Fluent button is composed entirely inside this language (§9 Button).
  static Widget _label(LanguageButtonSpec spec, LiveTheme theme, {Color? foreground}) {
    final step = theme.text.label.fontSize ?? 14;
    if (spec.loading) {
      return SizedBox.square(dimension: step, child: const fluent.ProgressRing(strokeWidth: 2));
    }
    if (spec.iconOnly) {
      return Icon(
        spec.icon,
        size: step,
        color: foreground,
        semanticLabel: spec.tooltip ?? (spec.label.isEmpty ? null : spec.label),
      );
    }
    final text = Text(spec.label, overflow: TextOverflow.ellipsis);
    if (spec.icon == null) {
      return text;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(spec.icon, size: step, color: foreground),
        SizedBox(width: theme.token.scale.sizes.xs),
        Flexible(child: text),
      ],
    );
  }
}
