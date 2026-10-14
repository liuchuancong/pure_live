import 'package:flutter/widgets.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/styling.dart';

/// Builds a frosted glass button from a [LanguageButtonSpec] (§9 Button). The
/// press and label logic come from the shared seam; padding is token-driven.
///
/// `expand` wraps the button in a full-width box and `tooltip` wraps it in the
/// core's language-neutral [LiveTooltip]; `GlassButton` exposes neither a hint
/// slot nor a focus parameter, so `focusNode`/`autofocus` are recorded as
/// unmappable (§9/§15) rather than emulated by wrapping the control in a second
/// focus node that would not drive activation.
abstract final class GlassButtonBuilder {
  /// Builds the button for [spec]; [seam] supplies shared label/state logic.
  static Widget build(BuildContext context, LanguageButtonSpec spec, SharedLanguageAdapter seam) {
    final theme = LiveTheme.of(context);
    Widget button = glass.GlassButton(
      onPressed: seam.interactive(spec) ? spec.onPressed : null,
      padding: EdgeInsets.symmetric(horizontal: theme.button.paddingInline, vertical: theme.token.scale.sizes.sm),
      child: seam.buttonLabel(spec, theme),
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
}
