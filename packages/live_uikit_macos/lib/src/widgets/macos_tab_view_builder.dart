import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Builds the macOS page switcher for a [LanguageTabViewSpec] (§9 Tab view).
///
/// Composed, not mapped. The library does have a view — `MacosTabView`
/// (`lib/src/layout/tab_view/tab_view.dart`) — but it is the whole control, not
/// this contract's half of it: it takes the `List<MacosTab>` strip *and* the
/// `List<Widget>` bodies in one widget and drives them from a
/// `MacosTabController` it asserts its `length` against, so the selection state
/// would live in the library rather than in the caller's index, and the strip this
/// package already answers for (`MacosTabBarBuilder`) would be drawn twice. `LanguageTabViewSpec` hands over pages and an index and keeps the
/// controller outside, which is exactly the shape that widget cannot take.
///
/// So the pane is assembled from the library's own numbers, read off
/// `tab_view.dart`: the 5pt radius, the hairline and the fill it resolves per
/// brightness, wrapped in the 12pt inset it gives its body, over an `IndexedStack`
/// that keeps every page mounted — the pane a macOS tab view shows, with the
/// pages behind it alive so their own state survives a change of index.
///
/// Two spec fields are deliberately not drawn, both because macOS does not do
/// the thing: [LanguageTabViewSpec.onIndexChanged] reports a page moved by the
/// viewer, and a macOS pane is never dragged — the strip (and only the strip)
/// moves it, through the caller — and [LanguageTabViewSpec.duration] is how long
/// a change takes where the language animates one, which the library's own view
/// does not: its body swap is a `setState` on the index, no cross-fade, no slide.
/// A page index outside `pages` is clamped rather than thrown at, and no pages at
/// all is an empty box, because the strip and the view are driven separately and a
/// frame where the two disagree must not take the window down.
abstract final class MacosTabViewBuilder {
  /// Builds the view for [spec].
  static Widget build(BuildContext context, LanguageTabViewSpec spec) {
    final pages = spec.pages;
    if (pages.isEmpty) {
      return const SizedBox.shrink();
    }
    final index = spec.index.clamp(0, pages.length - 1);
    final brightness = macos.MacosTheme.brightnessOf(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: brightness.resolve(const Color(0xFFE6E9EA), const Color(0xFF2B2E33)),
        border: Border.all(color: brightness.resolve(const Color(0xFFE1E2E4), const Color(0xFF3E4045))),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: IndexedStack(index: index, children: pages),
      ),
    );
  }
}
