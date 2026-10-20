import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_library/live_library.dart' show FollowArea;
import 'package:live_sites/live_sites.dart' show LiveArea, LiveAreaIdentity, LiveSite;
import 'package:pure_live/app/preferences/app_preferences_providers.dart' show appPreferencesProvider;
import 'package:pure_live/app/providers/app_providers.dart' show sitesProvider;
import 'package:pure_live/app/routing/app_router.dart' show AreaRoomsRoute, AreasRoute;
import 'package:pure_live/app/shell/main_layout.dart' show MainLayout;
import 'package:pure_live/features/areas/area_card.dart';
import 'package:pure_live/features/areas/areas_common.dart' show followedAreasProvider, toggleAreaFollow;
import 'package:pure_live/features/hot_areas/hot_areas_page.dart' show HotAreasPage;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The followed partitions (the reference's `FavoriteAreasPage`): "全部" and
/// one tab per platform that has them, in the platform-display order, over
/// the area tiles. A tile opens its rooms; a long press or right click drops
/// the follow, which asks first.
///
/// The list is the library's own, so the page needs no refresh: a name is
/// whatever the platform reported when the follow was made, and a partition
/// renamed since keeps the old name until it is followed again — the price of
/// opening a list without a round-trip.
final class FollowedAreasPage extends ConsumerStatefulWidget {
  /// The followed-partitions page.
  const new({super.key});

  @override
  ConsumerState<FollowedAreasPage> createState() => _FollowedAreasPageState();
}

final class _FollowedAreasPageState extends ConsumerState<FollowedAreasPage> {
  static const _all = '';

  int _selected = 0;

  /// The platform ids with a followed partition: the ordered registry first,
  /// ids the registry no longer knows behind them, so a retired platform's
  /// follows stay reachable instead of vanishing from the list.
  static List<String> _tabs(List<FollowArea> areas, List<LiveSite> orderedSites) {
    final present = {for (final area in areas) area.platform};
    if (present.isEmpty) {
      return const [];
    }
    final ids = [
      for (final site in orderedSites)
        if (present.contains(site.manifest.id)) site.manifest.id,
    ];
    ids.addAll([
      for (final id in present.toList()..sort())
        if (!ids.contains(id)) id,
    ]);
    return [_all, ...ids];
  }

  static LiveArea _asLiveArea(FollowArea area) =>
      LiveArea.normalized(platform: area.platform, areaId: area.areaId, areaName: area.name);

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final areas = ref.watch(followedAreasProvider).value ?? const <FollowArea>[];
    final preferences = ref.watch(appPreferencesProvider);
    final sites = HotAreasPage.orderedSites(ref.watch(sitesProvider).registry.all, preferences.siteOrder);
    final names = {for (final site in sites) site.manifest.id: site.manifest.localizedName(_tag(context), 'zh-CN')};
    final tabs = _tabs(areas, sites);
    final index = tabs.isEmpty ? 0 : _selected.clamp(0, tabs.length - 1);
    final selected = tabs.isEmpty ? _all : tabs[index];
    final shown = [
      for (final area in areas)
        if (selected == _all || area.platform == selected) area,
    ];

    Widget grid(List<FollowArea> list) => LayoutBuilder(
      builder: (context, constraints) {
        final gutter = MainLayout.gutterOf(context);
        final width = constraints.maxWidth;
        final columns = AreaGridMetrics.columnsFor(width);
        const spacing = PureSpacing.sm;
        final itemWidth = (width - 2 * gutter - spacing * (columns - 1)) / columns;
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(gutter, PureSpacing.sm, gutter, PureSpacing.xl),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: AreaGridMetrics.mainAxisExtent(itemWidth, MediaQuery.textScalerOf(context)),
          ),
          itemCount: list.length,
          itemBuilder: (context, position) {
            final area = list[position];
            final live = _asLiveArea(area);
            return GestureDetector(
              onLongPress: () => toggleAreaFollow(context, ref, live),
              onSecondaryTap: () => toggleAreaFollow(context, ref, live),
              child: AreaCard(
                key: ValueKey(live.identityKey),
                area: live,
                // In "全部" the platform is the fact the tile cannot show
                // otherwise; a platform's own tab needs no caption.
                subtitle: selected == _all ? (names[area.platform] ?? area.platform) : '',
                onOpen: () =>
                    AreaRoomsRoute(siteId: area.platform, areaId: area.areaId, areaName: area.name).push<void>(context),
              ),
            );
          },
        );
      },
    );

    return PureScaffold(
      appBar: PureAppBar(title: t.areas.followedAreas),
      body: areas.isEmpty
          ? PureEmpty(
              title: t.areas.followEmpty,
              message: t.areas.followEmptyHint,
              icon: Icons.apps_outlined,
              action: PureButton(
                label: t.tabs.areas,
                icon: Icons.category_outlined,
                onPressed: () => const AreasRoute().go(context),
              ),
            )
          : Column(
              children: [
                SizedBox(
                  height: 48,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(MainLayout.gutterOf(context), 4, MainLayout.gutterOf(context), 0),
                    child: PureTabs(
                      index: index,
                      isScrollable: true,
                      onChanged: (value) => setState(() => _selected = value),
                      tabs: [for (final id in tabs) PureTab(label: id == _all ? t.follow.all : (names[id] ?? id))],
                    ),
                  ),
                ),
                Expanded(child: grid(shown)),
              ],
            ),
    );
  }

  static String _tag(BuildContext context) => Localizations.localeOf(context).toLanguageTag();
}
