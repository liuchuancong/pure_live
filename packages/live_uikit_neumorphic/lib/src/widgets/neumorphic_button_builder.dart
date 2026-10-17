import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/live_uikit.dart';

/// Builds a soft-embossed Neumorphic button from a [LanguageButtonSpec] (§9 Button).
///
/// **Mapped.** `NeuButton` is the library's own button, and its pressed state is
/// the style's whole answer to a tap. Press enabled-ness is decided here — enabled,
/// not loading, and holding a callback — because `NeuButton` takes a null `onPressed`
/// as its inert state. `expand` wraps the button in a full-width box
/// and `tooltip` wraps it in the core's language-neutral [LiveTooltip] —
/// `NeuButton` exposes no hint slot, and neither wrap changes the shadow surface.
/// `focusNode`/`autofocus` have no parameter to land on and are recorded as
/// unmappable (§15), as are `selected` and the inline [Style]: this widget paints
/// its own surface, and layering either onto it would mean hand-painting an overlay.
abstract final class NeumorphicButtonBuilder {
  /// Builds the button for [spec] with the library's own [neu.NeuButton].
  static Widget build(BuildContext context, LanguageButtonSpec spec) {
    final theme = LiveTheme.of(context);
    Widget button = neu.NeuButton(
      onPressed: spec.enabled && !spec.loading && spec.onPressed != null ? spec.onPressed : null,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.button.paddingInline, vertical: theme.token.scale.sizes.sm),
        child: _label(spec, theme),
      ),
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
  /// icon-only button, whose empty label is never painted. The library gives
  /// `NeuButton` a child and nothing else, and ships no spinner of its own, so the
  /// loading state is composed from its progress face (§9 Button).
  static Widget _label(LanguageButtonSpec spec, LiveTheme theme, {Color? foreground}) {
    final step = theme.text.label.fontSize ?? 14;
    if (spec.loading) {
      return SizedBox(
        width: step,
        child: neu.NeuProgressBar(height: 2, progressColor: foreground ?? theme.colors.primary),
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
