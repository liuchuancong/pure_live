import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/styling.dart';

/// Builds a Wind button from a [LanguageButtonSpec] (§9 Button). The press and
/// label logic come from the shared seam; padding is token-driven.
abstract final class WindButtonBuilder {
  /// Builds the button for [spec]; [seam] supplies shared label/state logic.
  static Widget build(BuildContext context, LanguageButtonSpec spec, SharedLanguageAdapter seam) {
    final theme = LiveTheme.of(context);
    return wind.WButton(
      onTap: seam.interactive(spec) ? spec.onPressed : null,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.button.paddingInline, vertical: theme.token.scale.sizes.sm),
        child: seam.buttonLabel(spec, theme),
      ),
    );
  }
}
