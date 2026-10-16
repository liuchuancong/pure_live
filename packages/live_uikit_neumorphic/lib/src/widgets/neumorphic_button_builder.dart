import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/live_uikit.dart';

/// Builds a soft-embossed Neumorphic button from a [LanguageButtonSpec]
/// (§9 Button). Press/label logic comes from the shared seam; padding is token-
/// driven. `expand` wraps the button in a full-width box and `tooltip` wraps it in
/// the core's language-neutral [LiveTooltip] — `NeuButton` exposes no hint slot,
/// and neither wrap changes the shadow surface. `focusNode`/`autofocus` have no
/// parameter to land on and are recorded as unmappable (§9/§15).
abstract final class NeumorphicButtonBuilder {
  /// Builds the button for [spec]; [seam] supplies shared label/state logic.
  static Widget build(BuildContext context, LanguageButtonSpec spec, SharedLanguageAdapter seam) {
    final theme = LiveTheme.of(context);
    Widget button = neu.NeuButton(
      onPressed: seam.interactive(spec) ? spec.onPressed : null,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.button.paddingInline, vertical: theme.token.scale.sizes.sm),
        child: seam.buttonLabel(spec, theme),
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
}
