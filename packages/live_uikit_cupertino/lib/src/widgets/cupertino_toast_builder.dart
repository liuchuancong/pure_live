import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds a Cupertino toast surface from a [LanguageToastSpec] (§9 Toast).
///
/// Composed, and only the surface: the overlay it floats in, the fade and the
/// removal timer stay in the core's `LiveToast.show`, which is why
/// [LanguageToastSpec.duration] is not read here. `cupertino_ui` 1.1.2 ships no
/// `CupertinoToast` — that is a community widget, not part of the fork — and iOS
/// itself has no transient message bar: what it has is the HUD, a blurred
/// rounded panel that appears over the content and fades out. That panel is
/// already in the library as [cu.CupertinoPopupSurface], the 13pt squircle
/// `UIContextMenu`-style popups are drawn on, with its own backdrop blur and
/// translucent white paint, so the surface is that widget rather than the shared
/// renderer's opaque pill.
///
/// The status colour and the message role come from the token, because the token
/// decides that `warning` looks like this app's `warning` in every language; the
/// glyphs are the library's own — `info`, `checkmark_circle`,
/// `exclamationmark_triangle`, `exclamationmark_circle`.
abstract final class CupertinoToastBuilder {
  /// Builds the toast surface for [spec].
  static Widget build(BuildContext context, LanguageToastSpec spec) {
    final theme = LiveTheme.of(context);
    final accent =
        spec.accent ??
        switch (spec.type) {
          LiveToastType.info => theme.colors.info,
          LiveToastType.success => theme.colors.success,
          LiveToastType.warning => theme.colors.warning,
          LiveToastType.error => theme.colors.error,
        };
    final body = theme.text.body.copyWith(color: theme.colors.text);

    return cu.CupertinoPopupSurface(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.md, vertical: theme.token.scale.sizes.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(spec.icon ?? _glyph(spec.type), color: accent, size: body.fontSize),
            SizedBox(width: theme.token.scale.sizes.sm),
            Flexible(child: Text(spec.message, style: body)),
          ],
        ),
      ),
    );
  }

  static IconData _glyph(LiveToastType type) => switch (type) {
    LiveToastType.info => cu.CupertinoIcons.info,
    LiveToastType.success => cu.CupertinoIcons.checkmark_circle,
    LiveToastType.warning => cu.CupertinoIcons.exclamationmark_triangle,
    LiveToastType.error => cu.CupertinoIcons.exclamationmark_circle,
  };
}
