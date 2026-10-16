import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds the page switcher a tab strip drives from a [LanguageTabViewSpec]
/// (§9 Tab view).
///
/// Composed, and deliberately so. The fork's one widget by that name,
/// `cu.CupertinoTabView`, is not this contract's thing: it builds a `Navigator`
/// per tab and takes its content from a `builder`/route table, so the caller's
/// finished pages would have to be turned into routes and the widget would keep
/// each tab's stack alive behind the contract's back — the spec says the caller
/// owns the index and the pages, and a language may decide only how a page
/// changes. iOS itself has no standalone page-switcher widget to map to either
/// (the swipe is a `UIScrollView` behaviour the app assembles), so the switcher is
/// composed from [PageView] — `package:flutter/widgets.dart`, no Material — and
/// given the library's own scroll chrome, `cu.CupertinoScrollBehavior`: no
/// overscroll glow and a `CupertinoScrollbar` where a desktop shows one, which is
/// what the shared token base gets wrong about a Cupertino page.
///
/// Every field is read. [LanguageTabViewSpec.pages] are the view's children, in
/// order; [LanguageTabViewSpec.index] is the page shown, and a change to it from
/// the caller animates across in [LanguageTabViewSpec.duration] — with a
/// decelerating curve, because an iOS page settles rather than easing in and out
/// the way the token base drives its own controller.
/// [LanguageTabViewSpec.onIndexChanged] reports a swipe back, and a null callback
/// or a single page makes the view non-swipeable, exactly as the contract's
/// wording asks. The one field with no counterpart is an empty [LanguageTabViewSpec.pages]:
/// [PageView] asserts a non-empty child list, so the switcher answers with nothing
/// rather than throwing — the shared base would have thrown on it too.
abstract final class CupertinoTabViewBuilder {
  /// Builds the page switcher for [spec].
  static Widget build(BuildContext context, LanguageTabViewSpec spec) => _CupertinoTabView(spec: spec);
}

/// The stateful half: the controller the spec's index drives.
class _CupertinoTabView extends StatefulWidget {
  const new({required this.spec});

  final LanguageTabViewSpec spec;

  @override
  State<_CupertinoTabView> createState() => _CupertinoTabViewState();
}

class _CupertinoTabViewState extends State<_CupertinoTabView> {
  late final PageController _controller = PageController(initialPage: _page(widget.spec));

  /// The index clamped into the pages actually given, so a stale index from the
  /// caller cannot throw inside the library's controller.
  static int _page(LanguageTabViewSpec spec) =>
      spec.pages.isEmpty ? 0 : spec.index.clamp(0, spec.pages.length - 1);

  @override
  void didUpdateWidget(_CupertinoTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final page = _page(widget.spec);
    if (_page(oldWidget.spec) == page || !_controller.hasClients || _controller.page == page.toDouble()) {
      return;
    }
    _controller.animateToPage(page, duration: widget.spec.duration, curve: Curves.easeOut);
  }

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
    final swipeable = spec.onIndexChanged != null && spec.pages.length > 1;
    return ScrollConfiguration(
      behavior: const cu.CupertinoScrollBehavior(),
      child: PageView(
        controller: _controller,
        // Paging stays the page physics — the library behaviour above supplies the
        // overscroll and the scrollbar, not the snap.
        physics: swipeable ? const PageScrollPhysics() : const NeverScrollableScrollPhysics(),
        onPageChanged: swipeable ? (page) => spec.onIndexChanged?.call(page) : null,
        children: spec.pages,
      ),
    );
  }
}
