import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Wind button from a [LanguageButtonSpec] (§9 Button). The press and
///
/// `WButton` owns its focus handling inside `WAnchor`, which creates and tracks
/// its own node, so neither `focusNode` nor `autofocus` has a slot to land on —
/// wrapping the button in an extra `Focus` would steal focus from the node that
/// actually handles activation. Both are recorded as unexpressible spec fields
/// (§9/§15) rather than faked; `expand` and `tooltip` are expressed through the
/// fork's own vocabulary and a plain [Tooltip] wrapper.
abstract final class WindButtonBuilder {
  /// Builds the button for [spec], drawn from this library's own widgets part for part.
  static Widget build(BuildContext context, LanguageButtonSpec spec) {
    final theme = LiveTheme.of(context);
    final interactive = spec.enabled && !spec.loading && spec.onPressed != null;
    Widget button = wind.WButton(
      onTap: interactive ? spec.onPressed : null,
      // The fork paints its own `disabled:` state from this flag, so it is set
      // from the same seam verdict that nulls the callback — one source of truth
      // label rather than a second spinner from the fork.
      disabled: !interactive,
      className: spec.expand ? 'w-full' : null,
      semanticLabel: spec.tooltip,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.button.paddingInline, vertical: theme.token.scale.sizes.sm),
        child: _label(spec, theme),
      ),
    );
    final hint = spec.tooltip;
    if (hint != null) {
      button = Tooltip(message: hint, child: button);
    }
    return button;
  }

  /// The button's content, built from this library's own parts: the label, an
  /// optional leading glyph, a spinner while loading, and the bare glyph of an
  /// icon-only button, whose empty label is never painted. There is no shared
  /// renderer to inherit this from any more, so this language composes it —
  /// the library ships no button spinner, so the loading state is composed from its own surface part (§9 Button).
  static Widget _label(LanguageButtonSpec spec, LiveTheme theme, {Color? foreground}) {
    final step = theme.text.label.fontSize ?? 14;
    if (spec.loading) {
      return SizedBox.square(
        dimension: step,
        child: wind.WDiv(
          className: 'w-full h-full rounded-full animate-pulse',
          backgroundColor: foreground ?? theme.colors.primary,
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
