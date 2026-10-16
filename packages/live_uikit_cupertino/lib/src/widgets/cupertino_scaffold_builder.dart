import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';

/// Builds a Cupertino page frame from a [LanguageScaffoldSpec] (§9 Scaffold).
///
/// `cu.CupertinoPageScaffold` owns the iOS bar behaviour the spec asks for —
/// the translucent nav bar, the scroll-under and the keyboard policy — and takes
/// the bar in its `navigationBar` slot.
///
/// Three fields have no slot in this widget and are handled rather than dropped:
/// the bottom strip (iOS puts one on `CupertinoTabScaffold`, a different widget,
/// so the frame stacks it under the page), the floating action (Cupertino has no
/// FAB; the core's overlay geometry places it) and
/// [LanguageScaffoldSpec.extendBodyBehindAppBar] (a Cupertino nav bar always
/// overlays the scrollable content, which is the iOS answer to that flag).
abstract final class CupertinoScaffoldBuilder {
  /// Builds the frame for [spec].
  static Widget build(BuildContext context, LanguageScaffoldSpec spec) {
    final theme = LiveTheme.of(context);

    // The nav-bar slot takes the library's own bar type. A bar from another
    // language is not one, so it goes above the content instead — which is what
    // the token frame does with it — rather than being dropped.
    final cu.ObstructingPreferredSizeWidget? navBar;
    final Widget body;
    switch (spec.appBar) {
      case final cu.ObstructingPreferredSizeWidget sized:
        navBar = sized;
        body = spec.body;
      case final Widget bar:
        navBar = null;
        body = Column(
          children: [
            bar,
            Expanded(child: spec.body),
          ],
        );
      case null:
        navBar = null;
        body = spec.body;
    }

    final page = cu.CupertinoPageScaffold(
      navigationBar: navBar,
      backgroundColor: spec.background ?? theme.colors.bgLayout,
      resizeToAvoidBottomInset: spec.avoidKeyboard,
      child: body,
    );

    final bottom = spec.bottomBar;
    final action = spec.floatingActionButton;
    final Widget frame;
    if (bottom == null) {
      frame = page;
    } else {
      frame = Column(
        children: [
          Expanded(child: page),
          bottom,
        ],
      );
    }
    if (action == null) {
      return frame;
    }
    final margin = LiveEnvironmentScope.maybeOf(context)?.geometry.pagePadding ?? theme.token.scale.sizes.md;
    return Stack(
      children: [
        Positioned.fill(child: frame),
        PositionedDirectional(bottom: margin, end: margin, child: action),
      ],
    );
  }
}
