import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app.dart' show browseLayoutProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart' show CardLayout, ChromeIconButton, LayoutToggle, LiveWindow;

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
/// reload while the window holds them, and on a narrow window the tabs alone
/// plus one more icon carrying the same actions. The same morphology the hot
/// rooms page uses, so a feed the viewer can restyle is a feed that offers the
/// restyle.
final class VodFeedToolbar extends ConsumerWidget {
  /// The toolbar over [tabs]; [onRefresh] reloads the feed shown and is null
  /// on a page that has nothing to reload yet, [showLayout] is false on a grid
  /// that has no second form, and [actions] are the page's own head-end
  /// actions — its condition entry, its cleanup — which sit before the reload.
  const VodFeedToolbar({
    required this.tabs,
    required this.onRefresh,
    this.showLayout = true,
    this.actions = const <VodFeedAction>[],
    super.key,
  });

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
    return SizedBox(
      height: 44,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!LiveWindow.stacksToolbar(constraints.maxWidth)) {
            return Row(
              children: [
                Expanded(child: tabs),
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
            );
          }
          if (head.isEmpty && layouts.isEmpty) return tabs;
          return Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(child: tabs),
              DsMenuAnchor(
                semanticLabel: t.common.more,
                align: DsAlign.end,
                items: [
                  for (final (index, action) in head.indexed) ...[
                    if (index > 0) const DsMenuDivider(),
                    DsMenuItem(leading: DsIcon(action.icon), label: Text(action.label), onPressed: action.onPressed),
                  ],
                  if (layouts.isNotEmpty) ...[
                    const DsMenuDivider(),
                    for (final (label, value) in layouts)
                      DsMenuItem(
                        label: Text(label),
                        checked: ref.watch(browseLayoutProvider) == value,
                        onPressed: () => unawaited(ref.read(browseLayoutProvider.notifier).set(value)),
                      ),
                  ],
                ],
                builder: (context, controller, _) => DsButton.icon(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  semanticLabel: t.common.more,
                  onPressed: controller.open,
                  icon: const DsIcon(DsIcons.ellipsisVertical),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
