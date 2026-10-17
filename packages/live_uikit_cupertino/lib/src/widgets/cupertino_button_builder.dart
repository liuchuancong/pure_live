import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds a native Cupertino UI button from a [LanguageButtonSpec] (§9 Button):
/// ghost → a plain [cu.CupertinoButton], otherwise the filled variant; press and
/// the fork's own parameters; `expand` fills the button to its parent's width and
/// `tooltip` shows through the core's language-neutral [LiveTooltip], since this
/// library has no hint widget and an SDK Material one does not belong in a
/// Cupertino subtree.
abstract final class CupertinoButtonBuilder {
  /// Builds the button for [spec], drawn from this library's own widgets part for part.
  static Widget build(BuildContext context, LanguageButtonSpec spec) {
    final theme = LiveTheme.of(context);
    final onPressed = spec.enabled && !spec.loading && spec.onPressed != null ? spec.onPressed : null;
    final ghost = spec.variant == ButtonVariant.ghost;
    final child = _label(spec, theme, foreground: ghost ? theme.colors.primary : null);
    Widget button = ghost
        ? cu.CupertinoButton(onPressed: onPressed, focusNode: spec.focusNode, autofocus: spec.autofocus, child: child)
        : cu.CupertinoButton.filled(
            onPressed: onPressed,
            focusNode: spec.focusNode,
            autofocus: spec.autofocus,
            child: child,
          );
    if (spec.expand) {
      button = SizedBox(width: double.infinity, child: button);
    }
    final hint = spec.tooltip;
    if (hint != null) {
      button = LiveTooltip(message: hint, child: button);
    }
    return button;
  }

  /// The button's content, built from this library's own parts: the label, an
  /// optional leading glyph, a spinner while loading, and the bare glyph of an
  /// icon-only button, whose empty label is never painted. This language composes
  /// the content from its own widgets — the loading state maps to the library's
  /// own spinner (§9 Button).
  static Widget _label(LanguageButtonSpec spec, LiveTheme theme, {Color? foreground}) {
    final step = theme.text.label.fontSize ?? 14;
    if (spec.loading) {
      return cu.CupertinoActivityIndicator(color: foreground);
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
