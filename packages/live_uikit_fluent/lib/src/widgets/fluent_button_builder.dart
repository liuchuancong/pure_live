import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds a native Fluent button from a [LanguageButtonSpec] (§9 Button).
///
/// Primary and danger map to `FilledButton`, secondary/ghost to `Button`; the
/// loading button behaves identically across every style. Business actions stay
/// in the spec's `onPressed` — never here.
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
      // `Button`, so the shared language-neutral tooltip wraps either class
      // identically rather than dropping the filled variant to get it (§9).
      button = LiveTooltip(message: hint, child: button);
    }
    return button;
  }

  /// The button's content, built from this library's own parts: the label, an
  /// optional leading glyph, a spinner while loading, and the bare glyph of an
  /// icon-only button, whose empty label is never painted. There is no shared
  /// renderer to inherit this from any more, so this language composes it —
  /// the loading state maps to the library's own spinner (§9 Button).
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
