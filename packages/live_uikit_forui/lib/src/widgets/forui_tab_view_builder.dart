import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds a ForUI page switcher from a [LanguageTabViewSpec] (§9 Tab view).
///
/// Composed, not mapped: in 0.27.5 the library has no content-side page widget. Its
/// only one is `FTabs`, and that is a *pair* — every `FTabEntry` carries the panel
/// under its own tab, so the strip owns the body. This contract splits the two: the
/// strip is `tabBar` (already `FTabs`, with an empty panel per entry) and the body is
/// this control, whose pages the caller builds and hands over without any labels for
/// the library to hang them on. Re-using `FTabs` here would have meant inventing a
/// second strip, so the view is the widgets-layer `PageView` and the pages stay
/// exactly what the caller passed — dispatched controls, which already carry the
/// language.
///
/// There is therefore nothing to theme: no library knob covers a page change, so
/// [LanguageTabViewSpec.duration] drives the library-free `PageController.animateToPage`
/// with the widgets-layer curve, and the view follows the caller's index rather than
/// owning a page of its own. As in the token base and in `tabBar`, a swipe is only
/// possible when the caller can receive one: no [LanguageTabViewSpec.onIndexChanged],
/// or a single page, and the physics refuse scroll and the callback is not wired.
abstract final class ForuiTabViewBuilder {
  /// Builds the page switcher for [spec].
  static Widget build(BuildContext context, LanguageTabViewSpec spec) => _ForuiPageView(spec: spec);
}

/// The controller-bearing half of [ForuiTabViewBuilder]: a `PageView` kept in step with
/// the spec's index, which is why the builder is a widget rather than a direct call —
/// the controller outlives a build and has to be disposed with this subtree.
class _ForuiPageView extends StatefulWidget {
  const new({required this.spec});

  final LanguageTabViewSpec spec;

  @override
  State<_ForuiPageView> createState() => _ForuiPageViewState();
}

class _ForuiPageViewState extends State<_ForuiPageView> {
  late final PageController _controller = PageController(initialPage: widget.spec.index);

  @override
  void didUpdateWidget(_ForuiPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = widget.spec.index;
    if (oldWidget.spec.index != index && !_atPage(index)) {
      _controller.animateToPage(index, duration: widget.spec.duration, curve: Curves.easeInOutCubic);
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
    final swipeable = spec.onIndexChanged != null && spec.pages.length > 1;
    return PageView(
      controller: _controller,
      physics: swipeable ? const PageScrollPhysics() : const NeverScrollableScrollPhysics(),
      onPageChanged: swipeable ? (index) => spec.onIndexChanged?.call(index) : null,
      children: spec.pages,
    );
  }
}
