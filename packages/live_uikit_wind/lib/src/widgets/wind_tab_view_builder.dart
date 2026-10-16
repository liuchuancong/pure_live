import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/live_uikit.dart';

/// Builds the Wind page switcher a tab strip drives (§9 Tab view).
///
/// Composed, not mapped. The fork has `WTabs`, but it is a *whole* tabbed
/// component: its `panelBuilder` is required and it welds the strip to the panel
/// it paints, while the core contract hands the two separately — the strip is
/// this package's `WindTabBarBuilder` and the caller owns the pages — so using it here would
/// draw a second strip and discard the one the caller built. There is no page
/// frame, no `Pivot`, no swipe gesture to take.
///
/// So the view is Flutter's own `PageView` (from `package:flutter/widgets.dart`,
/// not the Material one) — the widget that gives a Wind page the swipe its
/// neighbouring languages have — inside the library's own full-size column
/// container, whose `bg-white dark:bg-gray-900` pair is the panel surface and
/// whose `flex-1` share is what `Expanded` takes in the fork's composer. That is
/// the honest division: `PageView` supplies the mechanism Wind has no class for,
/// and every pixel of chrome stays the library's.
///
/// [LanguageTabViewSpec.onIndexChanged] is the reason a swipe is wired at all:
/// only a view that reports the page it landed on can move the strip. Without a
/// callback, or with a single page, the pages are inert (`NeverScrollableScrollPhysics`)
/// and keep their place. A `spec.index` that changes underneath a settled view is
/// animated through [LanguageTabViewSpec.duration], which is the contract's own
/// knob, and clamped rather than thrown at: the strip and the view are driven
/// separately, so a frame where the two disagree must not take the page down.
abstract final class WindTabViewBuilder {
  /// Builds the view for [spec].
  static Widget build(BuildContext context, LanguageTabViewSpec spec) => _WindTabView(spec: spec);
}

class _WindTabView extends StatefulWidget {
  const new({required this.spec});

  final LanguageTabViewSpec spec;

  @override
  State<_WindTabView> createState() => _WindTabViewState();
}

class _WindTabViewState extends State<_WindTabView> {
  late final PageController _controller = PageController(initialPage: _page(widget.spec));

  static int _page(LanguageTabViewSpec spec) {
    if (spec.pages.isEmpty) return 0;
    return spec.index.clamp(0, spec.pages.length - 1);
  }

  @override
  void didUpdateWidget(covariant _WindTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final page = _page(widget.spec);
    if (oldWidget.spec.pages.length != widget.spec.pages.length) {
      // The controller cannot re-page a list that changed shape under it.
      _controller.jumpToPage(page);
      return;
    }
    if (_controller.hasClients && _controller.page != page.toDouble()) {
      _controller.animateToPage(page, duration: widget.spec.duration, curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    if (spec.pages.isEmpty) return const SizedBox.shrink();
    final swipeable = spec.onIndexChanged != null && spec.pages.length > 1;
    return wind.WDiv(
      className: 'flex flex-col w-full h-full bg-white dark:bg-gray-900',
      children: [
        Expanded(
          child: PageView(
            controller: _controller,
            physics: swipeable ? const PageScrollPhysics() : const NeverScrollableScrollPhysics(),
            onPageChanged: swipeable ? spec.onIndexChanged : null,
            children: spec.pages,
          ),
        ),
      ],
    );
  }
}
