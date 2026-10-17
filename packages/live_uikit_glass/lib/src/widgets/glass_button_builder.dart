import 'package:flutter/widgets.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/live_uikit.dart';

/// Builds a frosted glass button from a [LanguageButtonSpec] (§9 Button). The
/// surface is `glass_morphism_plus`'s own [glass.GlassButton]; everything the
/// library's button does not carry is composed here.
///
/// `expand` wraps the button in a full-width box and `tooltip` wraps it in the
/// core's language-neutral [LiveTooltip]; `GlassButton` exposes neither a hint
/// slot nor a focus parameter, so `focusNode`/`autofocus` are recorded as
/// unmappable (§9/§15) rather than emulated by wrapping the control in a second
/// focus node that would not drive activation. `selected` has no frosted
/// affordance in this library and the inline `style` has no slot on a widget that
/// paints its own surface, so both draw as an ordinary button and are recorded as
/// unmapped here (§9/§15).
abstract final class GlassButtonBuilder {
  /// Builds the button for [spec]: the library's own [glass.GlassButton], carrying
  /// content this package composes around it.
  static Widget build(BuildContext context, LanguageButtonSpec spec) {
    final theme = LiveTheme.of(context);
    Widget button = glass.GlassButton(
      onPressed: spec.enabled && !spec.loading && spec.onPressed != null ? spec.onPressed : null,
      padding: EdgeInsets.symmetric(horizontal: theme.button.paddingInline, vertical: theme.token.scale.sizes.sm),
      child: _label(spec, theme),
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
  /// optional leading glyph, the loading plate, and the bare glyph of an
  /// icon-only button, whose empty label is never painted. The library ships no
  /// button spinner, so the loading state is built out of its own surface part
  /// here (§9 Button).
  static Widget _label(LanguageButtonSpec spec, LiveTheme theme, {Color? foreground}) {
    final step = theme.text.label.fontSize ?? 14;
    if (spec.loading) {
      return glass.GlassContainer(
        width: step,
        height: step,
        child: Center(
          child: SizedBox.square(
            dimension: step * 0.5,
            child: ColoredBox(color: foreground ?? theme.colors.primary),
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
