import 'package:flutter/widgets.dart';
import 'package:pure_uikit/src/styling/widgets/controls/pure_tab_bar.dart';

/// One tab of a [PureTabs] strip: a label with an optional leading icon.
@immutable
final class PureTab {
  /// A tab.
  const new({required this.label, this.icon, this.enabled = true});

  /// The tab label.
  final String label;

  /// An optional leading icon, drawn before the label.
  final IconData? icon;

  /// Whether this tab answers to input; false greys the cell out and keyboard
  /// traversal steps over it.
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      other is PureTab && other.label == label && other.icon == icon && other.enabled == enabled;

  @override
  int get hashCode => Object.hash(label, icon, enabled);
}

/// The kit's tab strip: a [PureTab]-shaped door into [PureTabBar]. Every
/// design language draws the pill bar's own strip — the ink-line page tab,
/// the accent bar riding the bottom edge, hover previewing the same ink —
/// so a page's tabs and the shell's tabs are one control. The strip stands
/// its tier's height where the caller reserved it and shrinks to a slot that
/// bounds it lower (a title row), the way [PureTabBar] does.
class PureTabs extends StatelessWidget {
  /// A tab strip.
  const new({
    required this.tabs,
    required this.index,
    required this.onChanged,
    this.enabled = true,
    this.isScrollable = false,
    super.key,
  });

  /// The tabs, in order.
  final List<PureTab> tabs;

  /// The selected index.
  final int index;

  /// Called with a tab's index when it is chosen; null renders the strip inert.
  final ValueChanged<int>? onChanged;

  /// Whether the strip responds to input; false greys every tab out.
  final bool enabled;

  /// Whether a long strip scrolls instead of squeezing its tabs.
  final bool isScrollable;

  @override
  Widget build(BuildContext context) {
    return PureTabBar(
      items: [
        for (final tab in tabs)
          PureTabBarItem(icon: tab.icon, label: tab.label, enabled: tab.enabled),
      ],
      index: index,
      onChanged: onChanged,
      enabled: enabled,
      isScrollable: isScrollable,
    );
  }
}

/// The page area behind a tab strip.
///
/// The content is a stack of the caller's pages, with only the selected one
/// visible. This is intentionally shared by every language: it owns no visual
/// component, only the page-stack mechanics the routers already rely on.
class PureTabView extends StatelessWidget {
  /// A tab view over [pages].
  const new({required this.index, required this.pages, this.onIndexChanged, super.key});

  /// The visible page index.
  final int index;

  /// The page widgets.
  final List<Widget> pages;

  /// Called when a swipe/page change selects another index. The stack itself
  /// never swipes — the strip above it reports the choice — so this is here
  /// for the callers that drive the index from their own gesture.
  final ValueChanged<int>? onIndexChanged;

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) {
      return const SizedBox.shrink();
    }
    return IndexedStack(index: index.clamp(0, pages.length - 1), sizing: StackFit.expand, children: pages);
  }
}
