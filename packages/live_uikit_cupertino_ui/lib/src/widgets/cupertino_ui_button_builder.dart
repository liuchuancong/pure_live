import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';

/// Builds a native Cupertino UI button from a [LanguageButtonSpec] (§9 Button):
/// ghost → a plain [cu.CupertinoButton], otherwise the filled variant; press and
/// label logic come from the shared seam.
abstract final class CupertinoUiButtonBuilder {
  /// Builds the button for [spec]; [seam] supplies shared label/state logic.
  static Widget build(BuildContext context, LanguageButtonSpec spec, SharedLanguageAdapter seam) {
    final theme = LiveTheme.of(context);
    final onPressed = seam.interactive(spec) ? spec.onPressed : null;
    final ghost = spec.variant == ButtonVariant.ghost;
    final child = seam.buttonLabel(spec, theme, foreground: ghost ? theme.colors.primary : null);
    return ghost
        ? cu.CupertinoButton(onPressed: onPressed, focusNode: spec.focusNode, autofocus: spec.autofocus, child: child)
        : cu.CupertinoButton.filled(
            onPressed: onPressed,
            focusNode: spec.focusNode,
            autofocus: spec.autofocus,
            child: child,
          );
  }
}
