import 'package:flutter/widgets.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/styling.dart';

/// Builds a frosted glass button from a [LanguageButtonSpec] (§9 Button). The
/// press/label logic comes from the shared seam; padding is token-driven.
abstract final class GlassButtonBuilder {
  /// Builds the button for [spec]; [seam] supplies shared label/state logic.
  static Widget build(BuildContext context, LanguageButtonSpec spec, SharedLanguageAdapter seam) {
    final theme = LiveTheme.of(context);
    return glass.GlassButton(
      onPressed: seam.interactive(spec) ? spec.onPressed : null,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.button.paddingInline, vertical: theme.token.scale.sizes.sm),
        child: seam.buttonLabel(spec, theme),
      ),
    );
  }
}
