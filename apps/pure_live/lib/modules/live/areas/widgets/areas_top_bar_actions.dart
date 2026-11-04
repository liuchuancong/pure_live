import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/settings/settings.dart' show sitesDisplayProvider, sitesOrderProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/areas/controllers/areas_controller.dart';
import 'package:pure_live/modules/live/areas/pages/areas_page.dart' show showAreasPlatformWall, showAreasSearchPanel;
import 'package:pure_live/shared/shared.dart';

/// The areas page's verbs in the phone's top bar: the refresh and the more
/// menu, drawn as the outlined buttons the follows page uses.
///
/// The page keeps its platform tabs line alone on a phone; these two ride up
/// here (after the bar's search) so the verbs are offered once.
final class AreasTopBarActions extends ConsumerWidget {
  /// Creates the actions.
  const AreasTopBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final view = ref.watch(areasViewProvider);
    final platform = ref.watch(areasSiteProvider);
    final tileLayout = ref.watch(areaLayoutProvider);
    // The platform list and its order are settings this bar follows live.
    ref
      ..watch(sitesDisplayProvider)
      ..watch(sitesOrderProvider);
    final ids = ref.watch(areasCatalogProvider.notifier).platformIds();
    final inPlatformView = view == AreasView.platform;
    final loading =
        inPlatformView && ref.watch(areasCatalogProvider.select((catalog) => catalog[platform]?.loading ?? false));
    final viewController = ref.read(areasViewProvider.notifier);
    final layoutController = ref.read(areaLayoutProvider.notifier);

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: DsSpace.s8,
      children: [
        DsButton.icon(
          variant: DsButtonVariant.secondary,
          size: DsSize.sm,
          semanticLabel: t.common.refresh,
          loading: loading,
          onPressed: loading
              ? null
              : () => unawaited(ref.read(areasCatalogProvider.notifier).refresh(ref.read(areasSiteProvider))),
          icon: const DsIcon(DsIcons.refreshCw, size: 16),
        ),
        DsMenuAnchor(
          semanticLabel: t.common.more,
          align: DsAlign.end,
          items: [
            DsMenuItem(
              leading: const DsIcon(DsIcons.search),
              label: Text(t.areas.searchHint),
              onPressed: () => unawaited(
                showAreasSearchPanel(context, initial: ref.read(areasInlineSearchProvider) ?? ''),
              ),
            ),
            const DsMenuDivider(),
            DsMenuItem(
              label: Text(t.areas.viewPlatform),
              checked: view == AreasView.platform,
              onPressed: () => viewController.selected = AreasView.platform,
            ),
            DsMenuItem(
              label: Text(t.areas.viewFollowed),
              checked: view == AreasView.followed,
              onPressed: () => viewController.selected = AreasView.followed,
            ),
            const DsMenuDivider(),
            // One entry, one popup, as the shared platform menu does.
            DsMenuItem(
              leading: const DsIcon(DsIcons.layoutGrid),
              label: Text(t.common.layout),
              onPressed: () => unawaited(
                showChoiceDialog<AreaCardLayout>(
                  context: context,
                  title: t.common.layout,
                  value: tileLayout,
                  options: [
                    DsSelectOption(value: AreaCardLayout.tile, label: t.areas.iconTop),
                    DsSelectOption(value: AreaCardLayout.row, label: t.areas.iconLeft),
                  ],
                ).then((picked) {
                  if (picked != null) unawaited(layoutController.set(picked));
                }),
              ),
            ),
            if (ids.isNotEmpty) ...[
              const DsMenuDivider(),
              DsMenuItem(
                leading: const DsIcon(DsIcons.antenna),
                label: Text(t.common.switchPlatform),
                onPressed: () => unawaited(showAreasPlatformWall(context, ref)),
              ),
            ],
          ],
          builder: (context, controller, _) => DsButton.icon(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            semanticLabel: t.common.more,
            onPressed: controller.open,
            icon: const DsIcon(DsIcons.ellipsisVertical),
          ),
        ),
      ],
    );
  }
}
