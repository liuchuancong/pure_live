import 'package:pure_live/common/index.dart';
import 'package:waterfall_flow/waterfall_flow.dart';
import 'package:pure_live/modules/areas/widgets/area_card.dart';
import 'package:pure_live/modules/areas/areas_list_controller.dart';

class AreaGridView extends StatefulWidget {
  final String tag;
  const AreaGridView(this.tag, {super.key});
  AreasListController get controller => Get.find<AreasListController>(tag: tag);

  bool get isFlatten => tag == Sites.douyinSite;

  @override
  State<AreaGridView> createState() => _AreaGridViewState();
}

class _AreaGridViewState extends State<AreaGridView> with TickerProviderStateMixin {
  TabController? _tabController;
  Worker? _listWorker;

  @override
  void initState() {
    super.initState();
    if (!widget.isFlatten) {
      _listWorker = ever(widget.controller.categories, (_) => _createTabController());
      _createTabController();
      widget.controller.tabIndex.addListener(_handleExternalIndexChange);
    }
  }

  void _createTabController() {
    if (widget.isFlatten) return;
    final list = widget.controller.categories;
    if (list.isEmpty) return;

    if (_tabController != null && _tabController!.length == list.length) {
      return;
    }

    if (_tabController != null) {
      _tabController!.removeListener(_handleInternalTabChange);
      _tabController!.dispose();
    }

    int initialIndex = widget.controller.tabIndex.value;
    if (initialIndex >= list.length) initialIndex = 0;

    _tabController = TabController(length: list.length, vsync: this, initialIndex: initialIndex);
    _tabController!.addListener(_handleInternalTabChange);

    if (mounted) setState(() {});
  }

  void _handleInternalTabChange() {
    if (_tabController == null || _tabController!.indexIsChanging) return;
    if (widget.controller.tabIndex.value != _tabController!.index) {
      widget.controller.tabIndex.value = _tabController!.index;
      widget.controller.currentPage = 1;
      widget.controller.loadData();
    }
  }

  void _handleExternalIndexChange() {
    if (_tabController == null) return;
    final targetIndex = widget.controller.tabIndex.value;
    if (_tabController!.index != targetIndex && targetIndex < _tabController!.length) {
      _tabController!.animateTo(targetIndex);
    }
  }

  @override
  void dispose() {
    if (!widget.isFlatten) {
      widget.controller.tabIndex.removeListener(_handleExternalIndexChange);
      _listWorker?.dispose();
      if (_tabController != null) {
        _tabController!.removeListener(_handleInternalTabChange);
        _tabController!.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isFlatten) {
      return BasePageView<AreasListController, LiveArea>(
        controller: widget.controller,
        enableRefresh: true,
        enableLoadMore: true,
        showScrollToTopBtn: true,
        showPageSizeSelector: true,
        pageSizeOptions: const [5, 10, 20, 30, 50],
        emptyBuilder: (context) => EmptyView(
          icon: Icons.area_chart_outlined,
          title: i18n("empty_areas_title"),
          subtitle: i18n("empty_areas_subtitle"),
        ),
        contentBuilder: (context, displayList, scrollController) {
          return buildFlattenAreasView(displayList, scrollController);
        },
      );
    }

    return Obx(() {
      final categoriesList = widget.controller.categories;

      if (categoriesList.isEmpty || _tabController == null || _tabController!.length != categoriesList.length) {
        return BasePageView<AreasListController, LiveArea>(
          controller: widget.controller,
          enableRefresh: true,
          enableLoadMore: false,
          showPageSizeSelector: false,
          pageSizeOptions: const [],
          emptyBuilder: (context) => EmptyView(
            icon: Icons.area_chart_outlined,
            title: i18n("empty_areas_title"),
            subtitle: i18n("empty_areas_subtitle"),
          ),
          contentBuilder: (context, displayList, scrollController) {
            return const SizedBox.shrink();
          },
        );
      }

      return Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: categoriesList.map((e) => Tab(text: e.name)).toList(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: categoriesList.asMap().entries.map((entry) {
                final index = entry.key;
                final category = entry.value;

                return BasePageView<AreasListController, LiveArea>(
                  key: ValueKey("area_page_${category.name}"),
                  controller: widget.controller,
                  enableRefresh: true,
                  enableLoadMore: true,
                  showScrollToTopBtn: true,
                  showPageSizeSelector: true,
                  pageSizeOptions: const [5, 10, 20, 30, 50],
                  emptyBuilder: (context) => EmptyView(
                    icon: Icons.area_chart_outlined,
                    title: i18n("empty_areas_title"),
                    subtitle: i18n("empty_areas_subtitle"),
                  ),
                  contentBuilder: (context, displayList, scrollController) {
                    final bool isCurrentTab = widget.controller.tabIndex.value == index;
                    final List<LiveArea> finalData = isCurrentTab
                        ? displayList
                        : category.children.take(widget.controller.pageSize.value).toList();

                    if (finalData.isEmpty) {
                      return EmptyView(
                        icon: Icons.area_chart_outlined,
                        title: i18n("empty_areas_title"),
                        subtitle: i18n("empty_areas_subtitle"),
                      );
                    }

                    return buildFlattenAreasView(finalData, scrollController);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      );
    });
  }

  Widget buildFlattenAreasView(List<LiveArea> childrenList, ScrollController scrollController) {
    return LayoutBuilder(
      builder: (context, constraint) {
        final width = constraint.maxWidth;
        final crossAxisCount = width > 1280 ? 9 : (width > 960 ? 7 : (width > 640 ? 5 : 3));

        return WaterfallFlow.builder(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          controller: scrollController,
          gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
            lastChildLayoutTypeBuilder: (index) => LastChildLayoutType.none,
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: SettingsService.to.theme.crossAxisSpacing.v,
            mainAxisSpacing: SettingsService.to.theme.mainAxisSpacing.v,
          ),
          itemCount: childrenList.length,
          itemBuilder: (context, index) => AreaCard(category: childrenList[index]),
        );
      },
    );
  }
}
