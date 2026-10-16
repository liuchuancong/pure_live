import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Neumorphic page frame from a [LanguageScaffoldSpec] (§9 Scaffold).
///
/// **Composed, not mapped.** The library ships no page frame — every widget in it
/// is a surface a caller places, and the only frame-shaped thing reachable from the
/// dependency is Material's own `Scaffold`. That is precisely the surface this
/// dispatch exists to remove: it would hand the page back its canvas colour, its
/// floating-action placement rule, its keyboard-resize policy, and the Material
/// ancestor every descendant then quietly leans on. So the frame is built from the
/// library's own plane — a `NeuContainer` on its own default flat face at zero depth,
/// which is [neu.NeuThemeData.baseColor] with no shadow pair behind it, i.e. the
/// page surface rather than a raised card — sized to the slot it is given, with the
/// already-dispatched bars stacked on top of it.
///
/// It renders inline: no Material `Scaffold`, no `Navigator`, no
/// `ScaffoldMessenger`, no overlay controller. The `NeuTheme` the plane and the bars
/// read is installed above the page by the adapter's `wrap`
/// (`NeumorphicThemeScope`), so a Neumorphic page framed here is themed by the
/// token, not by whatever application shell happens to be outside it.
///
/// Handled rather than dropped, field by field:
/// - [LanguageScaffoldSpec.appBar] and [LanguageScaffoldSpec.bottomBar] are stacked
///   above and below the body in a column. They are already-built widgets because
///   each is its own dispatched control, and the frame lays them out by flex rather
///   than by [PreferredSizeWidget.preferredSize] — which is what lets the Neumorphic
///   bar's own `bottom` strip work without one.
/// - [LanguageScaffoldSpec.body] is the only thing that scrolls or grows; it keeps
///   the safe-area policy the core frame uses (`top` unless a bar or an extended body
///   already handles the status inset, `bottom` unless a bar sits there), because
///   `NeuAppBar` pads its own top and the nav bar wraps its own bottom.
/// - [LanguageScaffoldSpec.avoidKeyboard]: this library has no frame that resizes, so
///   the policy is carried out here — the body takes the view's bottom inset as
///   padding and the floating action rides the same inset; false ignores the inset.
/// - [LanguageScaffoldSpec.extendBodyBehindAppBar]: the body becomes
///   [Positioned.fill] with the bar pinned to the top edge of the plane, so a cover
///   or a scroll view can reach the top; ignored when there is no bar to run under.
/// - [LanguageScaffoldSpec.floatingActionButton]: neither the library nor the plane
///   has a slot for it, so the core's overlay geometry places it at the trailing
///   bottom corner — [LiveEnvironmentScope]'s page padding, falling back to the
///   token's `md` — exactly where the shared frame puts one.
/// - [LanguageScaffoldSpec.background] maps onto the plane's `baseColor` rather than
///   onto a fill painted over it: overriding a surface in this style means changing
///   the surface. Null keeps the theme's base colour, which the token already drove.
abstract final class NeumorphicScaffoldBuilder {
  /// Builds the frame for [spec].
  static Widget build(BuildContext context, LanguageScaffoldSpec spec) {
    final theme = LiveTheme.of(context);
    final surface = neu.NeuTheme.of(context);
    final geometry = LiveEnvironmentScope.maybeOf(context)?.geometry;
    final margin = geometry?.pagePadding ?? theme.token.scale.sizes.md;
    final keyboard = spec.avoidKeyboard ? MediaQuery.viewInsetsOf(context).bottom : 0.0;
    final bar = spec.appBar;

    final content = Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: bar == null && !spec.extendBodyBehindAppBar,
        bottom: spec.bottomBar == null,
        child: spec.body,
      ),
    );

    Widget stacked;
    if (bar == null) {
      stacked = content;
    } else if (spec.extendBodyBehindAppBar) {
      stacked = Stack(
        children: [Positioned.fill(child: content), Positioned(top: 0, left: 0, right: 0, child: bar)],
      );
    } else {
      stacked = Column(children: [bar, Expanded(child: content)]);
    }

    final bottom = spec.bottomBar;
    if (bottom != null) {
      stacked = Column(children: [Expanded(child: stacked), bottom]);
    }

    final plane = neu.NeuContainer(
      width: double.infinity,
      height: double.infinity,
      baseColor: spec.background ?? surface.baseColor,
      depth: 0,
      distance: 0,
      // The library's own [neu.NeuThemeData.borderRadius] would round the corners of
      // whatever plane it paints, and a page is not a plane with corners: it is the
      // surface every other plane sits on. Zero radius plus zero depth is therefore
      // the base colour filling the slot, and nothing else.
      borderRadius: BorderRadius.zero,
      child: stacked,
    );

    final action = spec.floatingActionButton;
    if (action == null) {
      return plane;
    }
    return Stack(
      children: [
        Positioned.fill(child: plane),
        PositionedDirectional(bottom: margin + keyboard, end: margin, child: action),
      ],
    );
  }
}
