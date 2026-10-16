import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds a Cupertino bar from a [LanguageAppBarSpec] (§9 AppBar).
///
/// `cu.CupertinoNavigationBar` maps the spec's parts: `leading`, `middle` (the
/// title, which iOS centres by itself, so a null
/// [LanguageAppBarSpec.centerTitle] is left alone rather than forced),
/// `trailing` takes a single widget so the action list travels as a row, and
/// [LanguageAppBarSpec.bottom] lands in the library's own bottom slot.
///
/// It returns a `PreferredSizeWidget`, which is what
/// [LanguageScaffoldSpec.appBar] needs to enter the frame's navigation-bar
/// slot instead of being stacked over the content.
abstract final class CupertinoAppBarBuilder {
  /// Builds the bar for [spec].
  static Widget build(BuildContext context, LanguageAppBarSpec spec) {
    final theme = LiveTheme.of(context);
    return cu.CupertinoNavigationBar(
      leading: spec.leading,
      middle: Text(spec.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: switch (spec.actions) {
        [] => null,
        [final Widget only] => only,
        final List<Widget> actions => Row(mainAxisSize: MainAxisSize.min, children: actions),
      },
      bottom: switch (spec.bottom) {
        final cu.PreferredSizeWidget sized => sized,
        _ => null,
      },
      backgroundColor: spec.background ?? theme.colors.bgElevated,
    );
  }
}
