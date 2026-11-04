import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app.dart' show browseLayoutProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/page_head_actions.dart';
import 'package:pure_live/layouts/page_layout_scope.dart';
import 'package:pure_live/shared/shared.dart'
    show CardLayout, ChromeIconButton, LayoutToggle, NavigationItem, showActionsPanel;

/// The content tabs a feed page wears in [VodFeedToolbar]: the toolbar's row
/// is 44 tall, the bar starts at the page's own inset, and the hairline would
/// cut across only the tabs while the actions beside them sit on none.
const DsTabsStyle kVodFeedTabsStyle = DsTabsStyle(
  height: 44,
  padding: EdgeInsets.zero,
  dividerColor: Color(0x00000000),
);

/// One head-end action a feed page offers beside the reload: the same icon
/// button at the head's end on a wide window, the same item in the more menu
/// on a narrow one — a page's action is one thing with two renderings.
final class VodFeedAction {
  /// The action, named by [label] and run by [onPressed].
  const VodFeedAction({required this.icon, required this.label, required this.onPressed});

  /// The action's glyph.
  final DsIconData icon;

  /// What the action is called, on the button's lip and in the menu.
  final String label;

  /// Runs the action.
  final VoidCallback onPressed;
}

/// The video station's feed toolbar: its tabs at the head's start, the feed's
/// own controls at its end — the card/list switch, the page's actions and a
/// reload while the window holds them. A narrow page keeps its tabs alone and
/// hands the verbs to the shell's head line (the live module's phone rule):
/// the reload rides there as itself, everything else — the layout, the page's
/// own actions — behind one labelled 更多 that opens a panel, never a glyph
/// drop-down.
final class VodFeedToolbar extends ConsumerWidget {
  /// The toolbar over [tabs]; [onRefresh] reloads the feed shown and is null
  /// on a page that has nothing to reload yet, [showLayout] is false on a grid
  /// that has no second form, and [actions] are the page's own head-end
  /// actions — its condition entry, its cleanup — which sit before the reload.
  const VodFeedToolbar({
    required this.owner,
    required this.tabs,
    required this.onRefresh,
    this.showLayout = true,
    this.actions = const <VodFeedAction>[],
    super.key,
  });

  /// The menu entry this page is standing in for: the shell shows the head
  /// verbs only under the entry that published them.
  final NavigationItem owner;

  /// The page's tab row.
  final Widget tabs;

  /// Reloads the feed the page is showing; null leaves the reload out, so a
  /// page that has no query on the screen yet does not offer a dead button.
  final Future<void> Function()? onRefresh;

  /// Whether the feed switches between the card and the list layout.
  final bool showLayout;

  /// The page's own actions, in the order they stand at the head's end.
  final List<VodFeedAction> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final head = <VodFeedAction>[
      ...actions,
      if (onRefresh != null)
        VodFeedAction(icon: DsIcons.refresh, label: t.vod.refresh, onPressed: () => unawaited(onRefresh!())),
    ];
    final layouts = showLayout
        ? <(String, CardLayout)>[(t.common.layoutGrid, CardLayout.grid), (t.common.layoutList, CardLayout.list)]
        : const <(String, CardLayout)>[];
    final narrow = PageLayoutScope.isNarrow(context);
    final refresh = onRefresh == null
        ? null
        : DsButton.icon(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            semanticLabel: t.vod.refresh,
            onPressed: () => unawaited(onRefresh!()),
            icon: const DsIcon(DsIcons.refreshCw, size: 16),
          );
    final more = head.isEmpty && layouts.isEmpty
        ? null
        : DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            semanticLabel: t.common.more,
            leading: const DsIcon(DsIcons.chevronDown, size: 14),
            child: Text(t.common.more),
            onPressed: () => unawaited(
              showActionsPanel(
                context,
                title: t.common.more,
                children: [
                  if (head.isNotEmpty)
                    DsListSection(
                      children: [
                        for (final action in head)
                          DsListRow(
                            leading: DsIcon(action.icon, size: 16),
                            title: Text(action.label),
                            onPressed: () {
                              Navigator.of(context).pop();
                              action.onPressed();
                            },
                          ),
                      ],
                    ),
                  if (layouts.isNotEmpty)
                    DsListSection(
                      header: Text(t.common.layout),
                      children: [
                        for (final (label, value) in layouts)
                          DsListRow(
                            title: Text(label),
                            trailing: ref.watch(browseLayoutProvider) == value
                                ? const DsIcon(DsIcons.check, size: 16)
                                : null,
                            onPressed: () {
                              Navigator.of(context).pop();
                              unawaited(ref.read(browseLayoutProvider.notifier).set(value));
                            },
                          ),
                      ],
                    ),
                ],
              ),
            ),
          );
    if (narrow) publishPageHeadActions(context, ref, owner, [?refresh, ?more]);
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(child: tabs),
          if (!narrow) ...[
            if (layouts.isNotEmpty) ...[const SizedBox(width: DsSpace.s8), const LayoutToggle()],
            for (final action in head) ...[
              const SizedBox(width: DsSpace.s8),
              ChromeIconButton(
                icon: action.icon,
                semanticLabel: action.label,
                tooltip: action.label,
                onPressed: action.onPressed,
                size: 36,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
