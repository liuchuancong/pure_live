import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/styling.dart';

/// Builds a Wind button from a [LanguageButtonSpec] (§9 Button). The press and
/// label logic come from the shared seam; padding is token-driven.
///
/// `WButton` owns its focus handling inside `WAnchor`, which creates and tracks
/// its own node, so neither `focusNode` nor `autofocus` has a slot to land on —
/// wrapping the button in an extra `Focus` would steal focus from the node that
/// actually handles activation. Both are recorded as unexpressible spec fields
/// (§9/§15) rather than faked; `expand` and `tooltip` are expressed through the
/// fork's own vocabulary and a plain [Tooltip] wrapper.
abstract final class WindButtonBuilder {
  /// Builds the button for [spec]; [seam] supplies shared label/state logic.
  static Widget build(BuildContext context, LanguageButtonSpec spec, SharedLanguageAdapter seam) {
    final theme = LiveTheme.of(context);
    final interactive = seam.interactive(spec);
    Widget button = wind.WButton(
      onTap: interactive ? spec.onPressed : null,
      // The fork paints its own `disabled:` state from this flag, so it is set
      // from the same seam verdict that nulls the callback — one source of truth
      // for "pressable" (§2.3). `loading` stays with the seam's spinner in the
      // label rather than a second spinner from the fork.
      disabled: !interactive,
      className: spec.expand ? 'w-full' : null,
      semanticLabel: spec.tooltip,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.button.paddingInline, vertical: theme.token.scale.sizes.sm),
        child: seam.buttonLabel(spec, theme),
      ),
    );
    final hint = spec.tooltip;
    if (hint != null) {
      button = Tooltip(message: hint, child: button);
    }
    return button;
  }
}
