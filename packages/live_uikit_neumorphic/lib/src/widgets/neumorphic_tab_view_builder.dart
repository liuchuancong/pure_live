import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/live_uikit.dart';

/// Builds the Neumorphic page switcher from a [LanguageTabViewSpec] (§9 Tab view).
///
/// **Composed, and paired with the strip on purpose.** The library ships no page
/// view, so the content is slid with Flutter's own `PageView` (a `widgets.dart`
/// scrollable, not a Material render widget) — the same mechanism the token base
/// uses, because a tab view swipes for a reason and refusing that would only make
/// this language's strip less capable than the fallback. What the language adds is
/// the surface it swipes across: the pages sit inside a `NeuContainer` on its
/// recessed ([neu.NeuShape.concave]) face, a well the content drops into, at the
/// theme's base colour, radius, depth and distance.
///
/// That recess is the whole point of the split from `tabBar`. The strip above this
/// view *domes* its chosen cell (`convex`, pressed out of the plane — see
/// `NeumorphicTabBarBuilder`); the page it reveals is the *inverse* reading, sunk
/// into a dish. Press the dome, see the plate. A Neumorphic page can therefore tell
/// its tab strip from the view it drives by touch alone, with no Material widget in
/// the subtree. [LanguageTabViewSpec.duration] is the caller's, not a theme value,
/// because the contract hands the change length to whoever owns the index.
///
/// [LanguageTabViewSpec.onIndexChanged] reports a viewer-driven swipe and is honoured
/// here — the view animates to whatever [LanguageTabViewSpec.index] the caller
/// supplies and never keeps a second copy of the index of its own, so a strip and a
/// view driven apart stay reconciled on the caller's next frame rather than drifting.
abstract final class NeumorphicTabViewBuilder {
  /// Builds the page view for [spec].
  static Widget build(BuildContext context, LanguageTabViewSpec spec) => _NeumorphicTabView(spec: spec);
}

class _NeumorphicTabView extends StatefulWidget {
  const new({required this.spec});

  final LanguageTabViewSpec spec;

  @override
  State<_NeumorphicTabView> createState() => _NeumorphicTabViewState();
}

class _NeumorphicTabViewState extends State<_NeumorphicTabView> {
  late final PageController _controller = PageController(initialPage: _clampedIndex);

  int get _clampedIndex {
    final pages = widget.spec.pages;
    if (pages.isEmpty) {
      return 0;
    }
    return widget.spec.index.clamp(0, pages.length - 1);
  }

  @override
  void didUpdateWidget(_NeumorphicTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = _clampedIndex;
    if (oldWidget.spec.index != index && !_atPage(index)) {
      _controller.animateToPage(
        index,
        duration: widget.spec.duration,
        curve: Curves.easeInOutCubic,
      );
    }
  }

  bool _atPage(int index) => _controller.hasClients && _controller.page == index.toDouble();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    if (spec.pages.isEmpty) {
      return const SizedBox.shrink();
    }
    final surface = neu.NeuTheme.of(context);
    final swipeable = spec.onIndexChanged != null && spec.pages.length > 1;

    return neu.NeuContainer(
      shape: neu.NeuShape.concave,
      baseColor: surface.baseColor,
      depth: surface.depth,
      distance: surface.distance,
      borderRadius: surface.borderRadius,
      padding: EdgeInsets.all(surface.depth),
      child: PageView(
        controller: _controller,
        physics: swipeable ? const PageScrollPhysics() : const NeverScrollableScrollPhysics(),
        onPageChanged: swipeable ? (index) => spec.onIndexChanged?.call(index) : null,
        children: spec.pages,
      ),
    );
  }
}
