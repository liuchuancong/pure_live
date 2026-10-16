import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds a Fluent page frame from a [LanguageScaffoldSpec] (§9 Scaffold).
///
/// `fluent.ScaffoldPage` is the library's own frame: the top slot is a
/// `PageHeader`-shaped widget (so [LanguageAppBarSpec]'s bar, whatever renders
/// it, sits where Fluent puts a page title), the bottom slot takes
/// [LanguageNavBarSpec]'s bar, and `resizeToAvoidBottomInset` is Fluent's name
/// for [LanguageScaffoldSpec.avoidKeyboard].
///
/// Three fields have no Fluent slot and are handled rather than dropped:
/// the floating action is placed by the core's own overlay geometry (Fluent
/// pages have no FAB), [LanguageScaffoldSpec.extendBodyBehindAppBar] is
/// ignored because Fluent draws its header inside the content column anyway, and
/// a [LanguageScaffoldSpec.background] override is painted behind the page since
/// `ScaffoldPage` takes its surface from `FluentTheme`.
abstract final class FluentScaffoldBuilder {
  /// Builds the frame for [spec].
  static Widget build(BuildContext context, LanguageScaffoldSpec spec) {
    final theme = LiveTheme.of(context);
    final page = fluent.ScaffoldPage(
      header: spec.appBar,
      bottomBar: spec.bottomBar,
      resizeToAvoidBottomInset: spec.avoidKeyboard,
      content: spec.body,
    );

    final surface = spec.background == null
        ? page
        : DecoratedBox(
            decoration: BoxDecoration(color: spec.background),
            child: page,
          );

    final action = spec.floatingActionButton;
    if (action == null) {
      return surface;
    }
    final margin = LiveEnvironmentScope.maybeOf(context)?.geometry.pagePadding ?? theme.token.scale.sizes.md;
    return Stack(
      children: [
        Positioned.fill(child: surface),
        PositionedDirectional(bottom: margin, end: margin, child: action),
      ],
    );
  }
}
