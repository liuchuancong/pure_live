import 'package:flutter/material.dart';
import 'package:pure_live/app/shell/home_views.dart';
import 'package:pure_live/app/shell/shell_actions.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The common frame for the four home tabs and the routed pages that share
/// their grammar, in the reference's shape: every page draws its own app
/// bar, and only as a phone home tab does that bar carry the shell's
/// buttons — the menu at the left, search and "more" at the right
/// (`showsHomeBarButtons`). On the rail the rail owns those actions, so the
/// bar keeps only the page's own title and tab strip.
///
/// The title slot is the reference's trick: a page may hand a
/// [titleWidget] (the follow page puts its live/replay/offline tab bar
/// there), otherwise the plain title text is drawn. [tabs] sits in the
/// bar's bottom slot — the reference's `appBar.bottom`.
class MainPageFrame extends StatelessWidget {
  /// Frames [body] for [title].
  const new({
    required this.title,
    required this.body,
    this.actions = const <Widget>[],
    this.titleWidget,
    this.tabs,
    this.tabIndex = 0,
    this.onTabChanged,
    this.showShellActions = true,
    this.inHome = false,
    super.key,
  });

  /// The page name.
  final String title;

  /// The page content, including its own scrolling/grid.
  final Widget body;

  /// Page-level actions shown at the end of the app bar.
  final List<Widget> actions;

  /// A widget to place in the title slot instead of the text (the reference
  /// puts the status tab bar there).
  final Widget? titleWidget;

  /// An optional tab strip for the bar's bottom slot.
  final List<PureTab>? tabs;

  /// The selected tab.
  final int tabIndex;

  /// Called when a tab is chosen.
  final ValueChanged<int>? onTabChanged;

  /// Adds the shell's search/more buttons to a phone home tab's bar.
  final bool showShellActions;

  /// Whether this page is mounted as a home tab (the reference's
  /// `inHome` route argument).
  final bool inHome;

  /// Whether the shell's buttons belong on this page's bar (the reference's
  /// `showsHomeBarButtons`): only as a home tab of the phone layout.
  static bool showsHomeBarButtons(BuildContext context, {required bool inHome}) {
    if (!inHome) return false;
    return HomeLayoutScope.maybeOf(context)?.phone ?? !isHomeRailWidth(MediaQuery.sizeOf(context).width);
  }

  @override
  Widget build(BuildContext context) {
    final shellButtons = showsHomeBarButtons(context, inHome: inHome);
    final tabs = this.tabs;
    return PureScaffold(
      appBar: PureAppBar(
        leading: shellButtons ? const HomeMenuButton() : null,
        title: title,
        titleWidget: titleWidget,
        actions: [
          if (shellButtons && showShellActions) const CommonAppBarActions(),
          ...actions,
        ],
        bottom: tabs == null || tabs.isEmpty
            ? null
            : PreferredSize(
                // PureTabs owns its own overflow (the Material family scrolls
                // inside the bounded bar); wrapping it in a horizontal scroll
                // view hands the strip unbounded width and the tab renderer
                // asserts.
                preferredSize: const Size.fromHeight(48),
                child: SizedBox(
                  height: 48,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: PureTabs(tabs: tabs, index: tabIndex, onChanged: onTabChanged),
                  ),
                ),
              ),
      ),
      body: body,
    );
  }
}
