import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Builds a macOS toast surface from a [LanguageToastSpec] (§9 Toast).
///
/// Composed, because `macos_ui` 2.2.2 has no transient message widget: its exports
/// carry no `Toast`, no `Banner` and no `Notification` (the 1.x `MacosToast` and
/// the `ToastOverlay` host it required are gone from the library). The surface
/// therefore takes the library's own floating panel, `MacosSheet`, which is what a
/// macOS HUD is drawn from — and it can be returned as a widget: the panel's
/// `build` reads only `MacosTheme` and `MediaQuery`, so unlike
/// `showMacosSheet` (a route, needing a `Navigator`) and unlike Material's
/// `SnackBar` (whose animation belongs to a `ScaffoldMessenger`, and which throws
/// when a caller-owned overlay mounts it) it does not require anything the core's
/// overlay does not already provide.
///
/// `insetPadding` is zero for the same reason it is zero on the card: the clearance
/// the sheet's default carries is the dialog route's job, and here the core's
/// `Align(topCenter)` does the placing, the fade does the timing and this widget is
/// only the surface.
///
/// The status colour is the token's — the token decides that `warning` looks like
/// this app's `warning` in every language — and the glyph is from the Cupertino set
/// macOS draws from, which `macos_ui` uses internally but does not re-export, so it
/// is taken straight from the SDK.
abstract final class MacosToastBuilder {
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

    return macos.MacosSheet(
      insetPadding: EdgeInsets.zero,
      backgroundColor: theme.colors.bgElevated,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.md, vertical: theme.token.scale.sizes.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            macos.MacosIcon(spec.icon ?? _glyph(spec.type), color: accent),
            SizedBox(width: theme.token.scale.sizes.sm),
            Flexible(child: Text(spec.message, style: body)),
          ],
        ),
      ),
    );
  }

  static IconData _glyph(LiveToastType type) => switch (type) {
    LiveToastType.info => CupertinoIcons.info_circle,
    LiveToastType.success => CupertinoIcons.checkmark_circle,
    LiveToastType.warning => CupertinoIcons.exclamationmark_triangle,
    LiveToastType.error => CupertinoIcons.xmark_circle,
  };
}
