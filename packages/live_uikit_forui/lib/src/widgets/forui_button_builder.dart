import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/live_uikit.dart';

/// Renders a [LanguageButtonSpec] with `FButton` (§9 Button).
abstract final class ForuiButtonBuilder {
  /// Builds the button, its content and its press eligibility.
  static Widget build(BuildContext context, LanguageButtonSpec spec) {
    final theme = LiveTheme.of(context);
    final interactive = spec.enabled && !spec.loading && spec.onPressed != null;
    // `onPress: null` is forui's own disabled state, and a loading button must not act;
    // no swallowing closure is ever invented to keep the widget looking live (§9).
    final onPress = interactive ? spec.onPressed : null;
    final content = _label(spec, theme);

    // The accessible name goes on the glyph the button carries, so the button
    // itself is not given a second `semanticsLabel` to announce twice.
    final button = spec.iconOnly
        // An icon-only control is forui's own variant, laid out by the library: squeezing
        // the token square (`iconEdge`) around a full `FButton` clipped the glyph, so this
        // language does not use that geometry (§9).
        ? forui.FButton.icon(
            onPress: onPress,
            variant: _variant(spec.variant),
            size: _size(spec.size),
            selected: spec.selected,
            focusNode: spec.focusNode,
            autofocus: spec.autofocus,
            child: content,
          )
        : forui.FButton(
            onPress: onPress,
            variant: _variant(spec.variant),
            size: _size(spec.size),
            // forui has a real selected affordance, so `selected` is mapped rather than
            // tinted by hand — the only adapter in the family that can say that (§9).
            selected: spec.selected,
            focusNode: spec.focusNode,
            autofocus: spec.autofocus,
            mainAxisSize: spec.expand ? MainAxisSize.max : MainAxisSize.min,
            child: content,
          );

    final hint = spec.tooltip;
    if (hint == null) {
      return button;
    }
    return forui.FTooltip(tipBuilder: (context, controller) => Text(hint), child: button);
  }

  /// The token variant as forui's closest kind. `secondary` maps to `outline`: the
  /// token model's secondary is a bordered supporting action, which is what forui's
  /// `outline` paints, while forui's own `secondary` is a muted fill the token has no
  /// role for (§9).
  static forui.FButtonVariant _variant(ButtonVariant variant) => switch (variant) {
    ButtonVariant.primary => forui.FButtonVariant.primary,
    ButtonVariant.secondary => forui.FButtonVariant.outline,
    ButtonVariant.ghost => forui.FButtonVariant.ghost,
    ButtonVariant.danger => forui.FButtonVariant.destructive,
  };

  static forui.FButtonSizeVariant _size(ControlSize size) => switch (size) {
    ControlSize.sm => forui.FButtonSizeVariant.sm,
    ControlSize.md => forui.FButtonSizeVariant.md,
    ControlSize.lg => forui.FButtonSizeVariant.lg,
  };

  /// The button's content, built from this library's own parts: the label, an
  /// optional leading glyph, a spinner while loading, and the bare glyph of an
  /// icon-only button, whose empty label is never painted. The contract's spec
  /// describes the content but does not draw it, so this builder composes it —
  /// the loading state maps to the library's own spinner (§9 Button).
  static Widget _label(LanguageButtonSpec spec, LiveTheme theme, {Color? foreground}) {
    final step = theme.text.label.fontSize ?? 14;
    if (spec.loading) {
      return SizedBox.square(
        dimension: step,
        child: forui.FProgress(
          style: forui.FProgressStyleDelta.delta(
            constraints: BoxConstraints.tightFor(width: step, height: step),
          ),
        ),
      );
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
