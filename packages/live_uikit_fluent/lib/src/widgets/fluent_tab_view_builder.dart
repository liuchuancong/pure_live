import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds the Fluent page switcher for a [LanguageTabViewSpec] (§9 Tab view).
///
/// Composed, not mapped: `fluent_ui` 4.16.1 ships no page-switcher widget — its
/// `TabView` is browser-style tabs with the body fused to the strip (the strip
/// half is what the package's own tab bar builder answers for), and this version
/// has no `Pivot`. The view is assembled from a plain `AnimatedSwitcher` keyed by
/// the page index, using the library's own motion vocabulary: Windows replaces a
/// tab body in place with a cross-fade (`FluentThemeData.fastAnimationDuration`
/// is what the library dialogs time their fades with), it never slides the pages
/// sideways, so there is no `PageView` and no shape change here.
///
/// [LanguageTabViewSpec.onIndexChanged] reports a viewer-driven swipe, which a
/// Fluent view does not have: the tab strip owns the index and the caller pumps
/// it through [LanguageTabViewSpec.index]. The duration is the spec's, not the
/// theme's, because the contract hands the change length to the caller.
abstract final class FluentTabViewBuilder {
  /// Builds the view for [spec].
  static Widget build(BuildContext context, LanguageTabViewSpec spec) => _FluentTabView(spec: spec);
}

class _FluentTabView extends StatelessWidget {
  const new({required this.spec});

  final LanguageTabViewSpec spec;

  @override
  Widget build(BuildContext context) {
    final pages = spec.pages;
    if (pages.isEmpty) return const SizedBox.shrink();
    // Clamp rather than throw: the strip and the view are driven separately, and
    // a frame where the two disagree briefly must not take the window down.
    final index = spec.index.clamp(0, pages.length - 1);
    return AnimatedSwitcher(
      duration: spec.duration,
      child: KeyedSubtree(key: ValueKey<int>(index), child: pages[index]),
    );
  }
}
