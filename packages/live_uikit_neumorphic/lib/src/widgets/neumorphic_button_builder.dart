import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/styling.dart';

/// Builds a soft-embossed Neumorphic button from a [LanguageButtonSpec]
/// (§9 Button). Press/label logic comes from the shared seam; padding is token-
/// driven.
abstract final class NeumorphicButtonBuilder {
  /// Builds the button for [spec]; [seam] supplies shared label/state logic.
  static Widget build(BuildContext context, LanguageButtonSpec spec, SharedLanguageAdapter seam) {
    final theme = LiveTheme.of(context);
    return neu.NeuButton(
      onPressed: seam.interactive(spec) ? spec.onPressed : null,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.button.paddingInline, vertical: theme.token.scale.sizes.sm),
        child: seam.buttonLabel(spec, theme),
      ),
    );
  }
}
