import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';

/// Builds a native Cupertino UI button from a [LanguageButtonSpec] (§9 Button):
/// ghost → a plain [cu.CupertinoButton], otherwise the filled variant; press and
/// label logic come from the shared seam. `focusNode` and `autofocus` are the
/// fork's own parameters; `expand` and `tooltip` wrap the button the way the
/// token renderer wraps its buttons — the tooltip through the core's
/// language-neutral [LiveTooltip], since this library has no hint widget and an
/// SDK Material one does not belong in a Cupertino subtree.
abstract final class CupertinoButtonBuilder {
  /// Builds the button for [spec]; [seam] supplies shared label/state logic.
  static Widget build(BuildContext context, LanguageButtonSpec spec, SharedLanguageAdapter seam) {
    final theme = LiveTheme.of(context);
    final onPressed = seam.interactive(spec) ? spec.onPressed : null;
    final ghost = spec.variant == ButtonVariant.ghost;
    final child = seam.buttonLabel(spec, theme, foreground: ghost ? theme.colors.primary : null);
    Widget button = ghost
        ? cu.CupertinoButton(onPressed: onPressed, focusNode: spec.focusNode, autofocus: spec.autofocus, child: child)
        : cu.CupertinoButton.filled(
            onPressed: onPressed,
            focusNode: spec.focusNode,
            autofocus: spec.autofocus,
            child: child,
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
