import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pure_live/app/routing/routes/search/search_routes.dart';
import 'package:pure_live/app/shell/main_layout.dart';
import 'package:pure_live/app/shell/main_workspace.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/platforms/adaptive/shell/adaptive_shell.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The common frame for the four main shell branches.
///
/// Under the workspace chrome the page keeps a compact in-content title row
/// plus its tab strip, leaving the fixed search/tools to [MainWorkspaceBar].
/// On a phone (no workspace chrome) the same title and tabs move into the
/// dispatched [PureAppBar], so the page still has one coherent top edge — and
/// when the shell carries a drawer, that app bar opens it.
///
/// From the expanded class up a page may hand a [pane]: a context column
/// (groups, sites, categories) that replaces the horizontal tab strip, the
/// desktop grammar of filter-left, content-right. Below the breakpoint the
/// same filter stays in the tab strip, so one page body serves every form.
class MainPageFrame extends StatelessWidget {
  /// Frames [body] for [title].
  const new({
    required this.title,
    required this.body,
    this.actions = const <Widget>[],
    this.tabs,
    this.tabIndex = 0,
    this.onTabChanged,
    this.pane,
    this.showSearchAction = true,
    super.key,
  });

  /// The page name.
  final String title;

  /// The page content, including its own scrolling/grid.
  final Widget body;

  /// Page-level actions shown at the end of the title row (or app bar).
  final List<Widget> actions;

  /// An optional tab strip; a single tab is still drawn so the page keeps a
  /// stable rhythm with the grouped catalogue pages.
  final List<PureTab>? tabs;

  /// The selected tab.
  final int tabIndex;

  /// Called when a tab is chosen.
  final ValueChanged<int>? onTabChanged;

  /// The context column a page shows instead of its tabs from the expanded
  /// class up. Null (or a compact window) keeps the tab strip.
  final Widget? pane;

  /// Adds the search entry to a phone app bar. The workspace bar already owns
  /// search on wide layouts.
  final bool showSearchAction;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final hasChrome = MainWorkspaceScope.hasChromeOf(context);
    final breakpoint = AdaptiveBreakpoints.of(context);
    final usePane = pane != null && breakpoint.isAtLeastExpanded;
    final gutter = MainLayout.gutterOf(context);
    final tabs = this.tabs;

    Widget? tabStrip;
    if (tabs != null && tabs.isNotEmpty && !usePane) {
      tabStrip = SizedBox(
        height: 48,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: hasChrome ? gutter : PureSpacing.md),
          child: PureTabs(tabs: tabs, index: tabIndex, onChanged: onTabChanged),
        ),
      );
    }

    if (!hasChrome) {
      final shell = AdaptiveShellScope.maybeOf(context);
      final drawerButton = shell != null && shell.hasDrawer
          ? IconButton(
              tooltip: context.t.common.menu,
              onPressed: shell.openDrawer,
              icon: const Icon(Icons.menu_rounded),
            )
          : null;
      return PureScaffold(
        appBar: PureAppBar(
          leading: drawerButton,
          title: title,
          actions: [
            if (showSearchAction)
              PureIconButton(
                icon: Icons.search_rounded,
                tooltip: context.t.tabs.search,
                onPressed: () => unawaited(const SearchRoute().push<void>(context)),
              ),
            ...actions,
          ],
          bottom: tabStrip == null ? null : PreferredSize(preferredSize: const Size.fromHeight(48), child: tabStrip),
        ),
        body: body,
      );
    }

    return ColoredBox(
      color: theme.colors.bgLayout,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(constraints.maxWidth, MainLayout.maxContentWidth);
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(gutter, PureSpacing.lg, gutter, PureSpacing.sm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.text.headline,
                            ),
                          ),
                        ),
                        if (actions.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var index = 0; index < actions.length; index++) ...[
                                if (index > 0) const SizedBox(width: PureSpacing.xs),
                                actions[index],
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: usePane
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(gutter, 0, PureSpacing.md, PureSpacing.xl),
                                child: pane,
                              ),
                              VerticalDivider(width: 1, color: theme.colors.border),
                              Expanded(child: body),
                            ],
                          )
                        : body,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
