import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/styling.dart';

/// Renders a [LanguageButtonSpec] with `FButton` (§9 Button).
abstract final class ForuiButtonBuilder {
  /// Builds the button for [spec], reusing the shared seam for label, icon-only
  /// content, disabled verdict and square geometry.
  static Widget build(BuildContext context, LanguageButtonSpec spec, SharedLanguageAdapter seam) {
    final theme = LiveTheme.of(context);
    final interactive = seam.interactive(spec);
    // `onPress: null` is forui's own disabled state, and a loading button must not act;
    // no swallowing closure is ever invented to keep the widget looking live (§9).
    final onPress = interactive ? spec.onPressed : null;
    final content = seam.buttonLabel(spec, theme);

    // forui names the accessible content on the glyph the seam builds, so the button
    // itself is not given a second `semanticsLabel` to announce twice.
    Widget button = spec.iconOnly
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
}
