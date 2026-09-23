import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:waterfall_flow/waterfall_flow.dart';
import 'package:pure_live/modules/areas/widgets/area_card.dart';
import 'package:pure_live/modules/areas/favorite_areas_controller.dart';

class FavoriteAreasPage extends GetView<FavoriteAreasController> {
  const FavoriteAreasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraint) {
        final width = constraint.maxWidth;
        final crossAxisCount = width > 1280 ? 9 : (width > 960 ? 7 : (width > 640 ? 5 : 3));
        return Scaffold(
          appBar: AppBar(title: Text(i18n("favorite_areas"))),
          body: Obx(() {
            final sites = Sites().availableSites(containsAll: true).toList(growable: false);
            return _FavoriteAreaSiteTabs(
              key: ValueKey(sites.map((site) => site.id).join('|')),
              controller: controller,
              sites: sites,
              crossAxisCount: crossAxisCount,
            );
          }),
        );
      },
    );
  }
}

@visibleForTesting
int resolveFavoriteAreaSiteIndex({
  required List<String> siteIds,
  required String selectedSiteId,
  required int fallback,
}) {
  if (siteIds.isEmpty) return 0;
  final selected = siteIds.indexOf(selectedSiteId);
  return selected >= 0 ? selected : fallback.clamp(0, siteIds.length - 1).toInt();
}

class _FavoriteAreaSiteTabs extends StatefulWidget {
  const _FavoriteAreaSiteTabs({super.key, required this.controller, required this.sites, required this.crossAxisCount});

  final FavoriteAreasController controller;
  final List<Site> sites;
  final int crossAxisCount;

  @override
  State<_FavoriteAreaSiteTabs> createState() => _FavoriteAreaSiteTabsState();
}

class _FavoriteAreaSiteTabsState extends State<_FavoriteAreaSiteTabs> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initialIndex = resolveFavoriteAreaSiteIndex(
      siteIds: widget.sites.map((site) => site.id).toList(growable: false),
      selectedSiteId: widget.controller.selectedSiteId,
      fallback: widget.controller.tabSiteIndex.value,
    );
    _tabController = TabController(
      length: widget.sites.length,
      initialIndex: initialIndex,
      vsync: this,
      animationDuration: pureLiveTabTransitionDuration,
    )..addListener(_handleTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.selectSite(initialIndex, widget.sites[initialIndex].id);
    });
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) return;
    final animationValue = _tabController.animation?.value ?? _tabController.index.toDouble();
    if ((animationValue - _tabController.index).abs() > 0.001) return;
    final index = _tabController.index;
    widget.controller.selectSite(index, widget.sites[index].id);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ScrollableTabBar(
          key: const ValueKey('favorite-areas-platform-tabs'),
          controller: _tabController,
          onTap: (index) => widget.controller.selectSite(index, widget.sites[index].id),
          isScrollable: true,
          physics: const PureLiveBoundedScrollPhysics(),
          tabs: widget.sites.map<Widget>((site) => Tab(text: site.name)).toList(growable: false),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const PureLiveBoundedScrollPhysics(),
            children: widget.sites
                .map((site) => _buildTabView(context, widget.controller, widget.crossAxisCount, site.id))
                .toList(growable: false),
          ),
        ),
      ],
    );
  }

  Widget _buildTabView(BuildContext context, FavoriteAreasController controller, int crossAxisCount, String siteId) {
    return Obx(() {
      final areas = siteId == Sites.allSite
          ? controller.favoriteAreas.toList(growable: false)
          : controller.favoriteAreas.where((area) => area.platform == siteId).toList(growable: false);
      return areas.isNotEmpty
          ? WaterfallFlow.builder(
              key: PageStorageKey('favorite_areas_$siteId'),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              physics: const PureLiveScrollPhysics(),
              gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                lastChildLayoutTypeBuilder: (index) => LastChildLayoutType.none,
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: SettingsService.to.theme.crossAxisSpacing.v,
                mainAxisSpacing: SettingsService.to.theme.mainAxisSpacing.v,
              ),
              itemCount: areas.length,
              itemBuilder: (context, index) {
                final area = areas[index];
                return AreaCard(key: ValueKey(area.identityKey ?? '$siteId:$index'), category: area);
              },
            )
          : EmptyView(icon: Remix.apps_2_line, title: i18n("empty_areas_title"), subtitle: '');
    });
  }
}
