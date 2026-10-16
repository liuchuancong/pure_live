import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a Material UI bar from a [LanguageAppBarSpec] (§9 AppBar).
///
/// The fork's `AppBar` is the one the contract was shaped around: `leading`,
/// `title`, `actions`, `centerTitle`, `bottom`, `toolbarHeight` and
/// `backgroundColor` are the spec's fields under their own names, so nothing has
/// to be approximated. A null [LanguageAppBarSpec.centerTitle] keeps Material's
/// own start alignment rather than second-guessing it.
///
/// It is returned as a `PreferredSizeWidget`, which is what
/// [LanguageScaffoldSpec.appBar] needs in order to sit in the frame's app-bar
/// slot rather than being stacked above the content.
abstract final class MaterialAppBarBuilder {
  /// Builds the bar for [spec].
  static Widget build(BuildContext context, LanguageAppBarSpec spec) {
    final theme = LiveTheme.of(context);
    return mu.AppBar(
      leading: spec.leading,
      title: Text(spec.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: spec.actions,
      centerTitle: spec.centerTitle,
      bottom: switch (spec.bottom) {
        final mu.PreferredSizeWidget sized => sized,
        _ => null,
      },
      toolbarHeight: spec.height,
      backgroundColor: spec.background ?? theme.colors.bgElevated,
    );
  }
}
