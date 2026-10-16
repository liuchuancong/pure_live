import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Builds a macOS bar from a [LanguageAppBarSpec] (§9 AppBar).
///
/// `macos_ui`'s in-scaffold bar is `ToolBar`, and its parts line up with the
/// spec: [LanguageAppBarSpec.leading] is `leading`, the title is a widget slot,
/// and [LanguageAppBarSpec.actions] ride in as `CustomToolbarItem`s — the
/// library's own escape hatch for widgets that are not one of its three toolbar
/// item kinds. A macOS bar centres its title by default, so
/// [LanguageAppBarSpec.centerTitle] is left null rather than forced to false.
///
/// [LanguageAppBarSpec.bottom] (a tab strip under the title) has no slot in a
/// `ToolBar`, so the bar is stacked with it and that pairing is documented here
/// rather than dropped: the strip still renders, in the language of whatever
/// adapter draws it.
abstract final class MacosAppBarBuilder {
  /// Builds the bar for [spec].
  static Widget build(BuildContext context, LanguageAppBarSpec spec) {
    final theme = LiveTheme.of(context);
    final height = spec.height ?? LiveEnvironmentScope.maybeOf(context)?.geometry.appBarHeight ?? 52;
    final bar = SizedBox(
      // `ToolBar`'s internal layout asks to be as tall as it can — fine inside
      // `MacosScaffold.toolBar`, which sizes it, but an assertion when a frame
      // stacks the bar in a column. A macOS bar has exactly one height and the
      // spec says what it is, so the widget states it rather than hoping its
      // parent bounds it.
      height: height,
      child: macos.ToolBar(
        height: height,
        title: Text(
          spec.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: theme.colors.text),
        ),
        leading: spec.leading,
        centerTitle: spec.centerTitle ?? true,
        decoration: spec.background == null ? null : BoxDecoration(color: spec.background),
        actions: [for (final action in spec.actions) macos.CustomToolbarItem(inToolbarBuilder: (_) => action)],
      ),
    );

    final bottom = spec.bottom;
    if (bottom == null) {
      return bar;
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [bar, bottom]);
  }
}
