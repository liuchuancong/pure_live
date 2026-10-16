import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a Material UI page switcher from a [LanguageTabViewSpec] (§9 Tabs).
///
/// The fork's `TabBarView` is the whole view — the page-to-page slide and the kept
/// alive neighbours are what make a Material tab view read as one — but it is
/// driven by a [mu.TabController] rather than by an index, so the controller lives
/// here and the spec's index is asserted onto it on every change, exactly as
/// `MaterialTabBarBuilder` does for the strip. The two do not share a controller:
/// `tabBar` and `tabView` are two controls of the contract, each controlled by its
/// own spec, so a page and a strip that are not siblings in the caller's tree still
/// follow the same index without either having to own the other.
///
/// The view stays controlled. A swipe moves the controller, which is reported back
/// through [LanguageTabViewSpec.onIndexChanged]; the caller's next rebuild either
/// agrees — the asserted index then equals the controller's and nothing moves — or
/// refuses, and the assertion pulls the page back to wherever the spec says, which
/// is also how a refused swipe is undone.
///
/// [LanguageTabViewSpec.duration] maps onto the controller's `animationDuration`,
/// the only place the fork keeps that knob; a length or a duration change rebuilds
/// the controller, because the fork reads both in its constructor.
///
/// [LanguageTabViewSpec.pages] of one, or no callback, leave the view non-
/// interactive: the fork's page scroll is switched off with a
/// [NeverScrollableScrollPhysics] rather than by dropping the pages.
abstract final class MaterialTabViewBuilder {
  /// Builds the page view for [spec].
  static Widget build(BuildContext context, LanguageTabViewSpec spec) => _ControlledTabView(spec: spec);
}

class _ControlledTabView extends StatefulWidget {
  const new({required this.spec});

  final LanguageTabViewSpec spec;

  @override
  State<_ControlledTabView> createState() => _ControlledTabViewState();
}

class _ControlledTabViewState extends State<_ControlledTabView> with SingleTickerProviderStateMixin {
  late mu.TabController _controller = _make();

  mu.TabController _make() => mu.TabController(
    length: widget.spec.pages.length,
    initialIndex: _inRange(widget.spec.index, widget.spec.pages.length),
    animationDuration: widget.spec.duration,
    vsync: this,
  )..addListener(_reportSwipe);

  // The fork asserts an in-range initial index; a spec from a shrinking page list
  // is clamped rather than allowed to crash the view (§15).
  static int _inRange(int index, int length) => length == 0 ? 0 : index.clamp(0, length - 1);

  void _reportSwipe() {
    final index = _controller.index;
    if (index != widget.spec.index) {
      widget.spec.onIndexChanged?.call(index);
    }
  }

  @override
  void didUpdateWidget(_ControlledTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spec.pages.length != widget.spec.pages.length ||
        oldWidget.spec.duration != widget.spec.duration) {
      _controller.dispose();
      _controller = _make();
    }
    final index = _inRange(widget.spec.index, widget.spec.pages.length);
    if (_controller.index != index) {
      _controller.index = index;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_reportSwipe);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final swipeable = spec.onIndexChanged != null && spec.pages.length > 1;
    return mu.TabBarView(
      controller: _controller,
      physics: swipeable ? null : const NeverScrollableScrollPhysics(),
      children: spec.pages,
    );
  }
}
