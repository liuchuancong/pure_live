import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app.dart' show browseLayoutProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart' show CardLayout, ChromeIconButton, LayoutToggle, LiveWindow;

/// The video station's feed toolbar: its tabs at the head's start, the feed's
/// own controls at its end — the card/list switch and a reload while the
/// window holds them, and on a narrow window the tabs alone plus one more icon
/// carrying the same actions. The same morphology the hot rooms page uses, so
/// a feed the viewer can restyle is a feed that offers the restyle.
final class VodFeedToolbar extends ConsumerWidget {
  /// The toolbar over [tabs]; [onRefresh] reloads the feed shown, and
  /// [showLayout] is false on a grid that has no second form.
  const VodFeedToolbar({required this.tabs, required this.onRefresh, this.showLayout = true, super.key});

  /// The page's tab row.
  final Widget tabs;

  /// Reloads the feed the page is showing.
  final Future<void> Function() onRefresh;

  /// Whether the feed switches between the card and the list layout.
  final bool showLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final refresh = ChromeIconButton(
      icon: DsIcons.refresh,
      semanticLabel: t.vod.refresh,
      tooltip: t.vod.refresh,
      onPressed: () => unawaited(onRefresh()),
      size: 36,
    );
    return SizedBox(
      height: 44,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!LiveWindow.stacksToolbar(constraints.maxWidth)) {
            return Row(
              children: [
                Expanded(child: tabs),
                if (showLayout) ...[const SizedBox(width: DsSpace.s8), const LayoutToggle()],
                const SizedBox(width: DsSpace.s8),
                refresh,
              ],
            );
          }
          return Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(child: tabs),
              DsMenuAnchor(
                semanticLabel: t.common.more,
                align: DsAlign.end,
                items: [
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.refresh),
                    label: Text(t.vod.refresh),
                    onPressed: () => unawaited(onRefresh()),
                  ),
                  if (showLayout) ...[
                    const DsMenuDivider(),
                    DsMenuItem(
                      label: Text(t.common.layoutGrid),
                      checked: ref.watch(browseLayoutProvider) == CardLayout.grid,
                      onPressed: () => unawaited(ref.read(browseLayoutProvider.notifier).set(CardLayout.grid)),
                    ),
                    DsMenuItem(
                      label: Text(t.common.layoutList),
                      checked: ref.watch(browseLayoutProvider) == CardLayout.list,
                      onPressed: () => unawaited(ref.read(browseLayoutProvider.notifier).set(CardLayout.list)),
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
