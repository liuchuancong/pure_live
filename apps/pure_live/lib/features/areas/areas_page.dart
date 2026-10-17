import 'dart:async' show unawaited;

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveArea, LiveAreaProvider, LiveSite;
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/routes/areas/areas_routes.dart';
import 'package:pure_live/features/areas/area_card.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// Areas: every area-capable platform as a tab over its category catalogue
/// (3.x `AreasPage`); a category tab row splits the platforms that group
/// their areas — one group's tiles at a time, like the reference — while a
/// flat catalogue is one grid. Pull to refresh reloads the catalogue.
final class AreasPage extends ConsumerStatefulWidget {
  /// The areas page.
  const new({super.key});

  @override
  ConsumerState<AreasPage> createState() => _AreasPageState();
}

final class _AreasPageState extends ConsumerState<AreasPage> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final sites = ref.watch(sitesProvider);
    final capable = sites.registry.all.where((site) => site.capability<LiveAreaProvider>() != null).toList();
    if (capable.isEmpty) {
      return PureScaffold(
        appBar: PureAppBar(title: context.t.tabs.areas, actions: const [SettingsEntryButton()]),
        body: PureEmpty(title: context.t.common.empty),
      );
    }
    final index = _selected.clamp(0, capable.length - 1);
    return PureScaffold(
      appBar: PureAppBar(
        title: context.t.tabs.areas,
        actions: const [SettingsEntryButton()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: PureTabs(
              index: index,
              onChanged: (value) => setState(() => _selected = value),
              tabs: [for (final site in capable) PureTab(label: site.manifest.localizedName(_tag(context), 'zh-CN'))],
            ),
          ),
        ),
      ),
      body: PureTabView(
        index: index,
        onIndexChanged: (value) => setState(() => _selected = value),
        pages: [for (final site in capable) _PlatformAreas(key: ValueKey(site.manifest.id), site: site)],
      ),
    );
  }

  static String _tag(BuildContext context) => Localizations.localeOf(context).toLanguageTag();
}

/// One platform's catalogue: its areas, grouped by their parent category.
final class _PlatformAreas extends StatefulWidget {
  /// A catalogue for [site].
  const new({required this.site, super.key});

  final LiveSite site;

  @override
  State<_PlatformAreas> createState() => _PlatformAreasState();
}

final class _PlatformAreasState extends State<_PlatformAreas> with AutomaticKeepAliveClientMixin {
  List<LiveArea>? _areas;
  Object? _error;

  /// The selected parent category, as the reference's category tab index:
  /// a grouped catalogue shows one group at a time and keeps its selection
  /// (clamped) across refreshes.
  int _selectedGroup = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
    });
    final capability = widget.site.capability<LiveAreaProvider>();
    if (capability == null) {
      return;
    }
    final result = await capability.getAreas();
    if (!mounted) {
      return;
    }
    setState(() {
      result.fold((error) {
        // A refresh over shown tiles keeps them; only a first load surfaces
        // the failure as a full view.
        if (_areas == null) {
          _error = error;
        }
      }, (areas) {
        _areas = areas;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final areas = _areas;
    if (areas == null) {
      if (_error != null) {
        return PureError(message: context.t.errors.network, onRetry: _load, retryLabel: context.t.common.retry);
      }
      return const PureLoading();
    }
    // The parent groups, in the order the site presents them; a platform
    // without parents is one group and shows no tab row.
    final groups = <String, List<LiveArea>>{};
    for (final area in areas) {
      final parent = area.parentAreaName ?? '';
      groups.putIfAbsent(parent, () => []).add(area);
    }
    if (areas.isEmpty) {
      return PureEmpty(
        title: context.t.areas.empty,
        icon: Icons.apps_outlined,
        action: PureButton(label: context.t.common.retry, icon: Icons.refresh, onPressed: _load),
      );
    }
    _selectedGroup = _selectedGroup.clamp(0, groups.length - 1);
    final parents = groups.keys.toList(growable: false);
    final selectedParent = parents[_selectedGroup];
    final visible = groups.length > 1 ? groups[selectedParent]! : groups.values.expand((list) => list).toList();
    return Column(
      children: [
        if (groups.length > 1)
          SizedBox(
            height: 48,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: PureTabs(
                index: _selectedGroup,
                onChanged: (value) => setState(() => _selectedGroup = value),
                tabs: [
                  for (final parent in parents) PureTab(label: parent.isEmpty ? context.t.tabs.areas : parent),
                ],
              ),
            ),
          ),
        Expanded(
          child: CustomRefreshIndicator(
            onRefresh: _load,
            builder: (context, child, indicator) => Stack(
              alignment: Alignment.topCenter,
              children: [
                child,
                Positioned(
                  top: 12,
                  child: Opacity(
                    opacity: indicator.value.clamp(0, 1),
                    child: IgnorePointer(child: PureProgress(value: indicator.isLoading ? null : indicator.value)),
                  ),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = AreaGridMetrics.columnsFor(width);
                const spacing = PureSpacing.sm;
                final itemWidth = (width - 2 * spacing - spacing * (columns - 1)) / columns;
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(PureSpacing.sm, PureSpacing.sm, PureSpacing.sm, PureSpacing.xl),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    mainAxisExtent: AreaGridMetrics.mainAxisExtent(itemWidth, MediaQuery.textScalerOf(context)),
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final area = visible[index];
                    return AreaCard(
                      key: ValueKey('${area.platform}:${area.areaId}'),
                      area: area,
                      onOpen: () => AreaRoomsRoute(
                        siteId: area.platform,
                        areaId: area.areaId,
                        areaName: area.areaName,
                      ).push<void>(context),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
