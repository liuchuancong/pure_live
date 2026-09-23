import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
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
  final Map<String, ScrollController> _categoryScrollControllers = {};
  final Set<ScrollController> _retiredScrollControllers = {};

  ScrollController _scrollControllerFor(String categoryId) =>
      _categoryScrollControllers.putIfAbsent(categoryId, () => createPureLiveScrollController());

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
    final recreateTabs = _tabController?.length != list.length;
    if (recreateTabs || list.isEmpty) {
      _tabController?.removeListener(_handleInternalTabChange);
      _tabController?.dispose();
      _tabController = null;
    }

    if (list.isEmpty) {
      widget.controller.bindActiveScrollController(null);
    } else {
      int initialIndex = widget.controller.tabIndex.value;
      if (initialIndex < 0 || initialIndex >= list.length) initialIndex = 0;
      if (_tabController == null) {
        _tabController = TabController(
          length: list.length,
          vsync: this,
          initialIndex: initialIndex,
          animationDuration: pureLiveTabTransitionDuration,
        );
        _tabController!.addListener(_handleInternalTabChange);
      }
      // Equal lengths do not imply equal category identities. Rebind even
      // when the tab animation controller can be reused.
      widget.controller.bindActiveScrollController(_scrollControllerFor(list[initialIndex].id));
    }
    _retireRemovedCategories(list.map((category) => category.id).toSet());

    if (mounted && (recreateTabs || list.isEmpty)) setState(() {});
  }

  void _retireRemovedCategories(Set<String> retainedIds) {
    final removedIds = _categoryScrollControllers.keys.where((id) => !retainedIds.contains(id)).toList();
    if (removedIds.isEmpty) return;
    final removed = removedIds.map((id) => _categoryScrollControllers.remove(id)!).toList();
    _retiredScrollControllers.addAll(removed);
    // The old PageView children detach during the next layout. Release their
    // controllers afterwards, rather than disposing a still-mounted position.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in removed) {
        if (_retiredScrollControllers.remove(controller)) controller.dispose();
      }
    });
  }

  void _handleInternalTabChange() {
    if (_tabController == null || _tabController!.indexIsChanging) return;
    final animationValue = _tabController!.animation?.value ?? _tabController!.index.toDouble();
    if ((animationValue - _tabController!.index).abs() > 0.001) return;
    final target = _tabController!.index;
    final categories = widget.controller.categories;
    if (target < 0 || target >= categories.length) return;
    widget.controller.bindActiveScrollController(_scrollControllerFor(categories[target].id));
    if (widget.controller.tabIndex.value != target) {
      // Category data is already local. Commit only after the horizontal
      // gesture settles, and bind the destination's dedicated controller so
      // offsets never leak between PageView children.
      widget.controller.selectCategory(target);
    }
  }

  void _handleExternalIndexChange() {
    if (_tabController == null) return;
    final targetIndex = widget.controller.tabIndex.value;
    final categories = widget.controller.categories;
    if (targetIndex < 0 || targetIndex >= categories.length) return;
    widget.controller.bindActiveScrollController(_scrollControllerFor(categories[targetIndex].id));
    if (_tabController!.index != targetIndex && targetIndex < _tabController!.length) {
      _tabController!.animateTo(targetIndex);
    }
  }

  @override
  void dispose() {
    if (!widget.isFlatten) {
      widget.controller.bindActiveScrollController(null);
      widget.controller.tabIndex.removeListener(_handleExternalIndexChange);
      _listWorker?.dispose();
      if (_tabController != null) {
        _tabController!.removeListener(_handleInternalTabChange);
        _tabController!.dispose();
      }
    }
    for (final controller in _categoryScrollControllers.values) {
      controller.dispose();
    }
    _categoryScrollControllers.clear();
    for (final controller in _retiredScrollControllers) {
      controller.dispose();
    }
    _retiredScrollControllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isFlatten) {
      return BasePageView<AreasListController, LiveArea>(
        controller: widget.controller,
        enableRefresh: true,
        enableLoadMore: true,
        customMobileBottomPadding: 85,
        customDesktopBottomPadding: 135,
        showScrollToTopBtn: SettingsService.to.page.showScrollToTopBtn.v,
        showPageSizeSelector: SettingsService.to.page.showPageSizeSelector.v,
        pageSizeOptions: SettingsService.to.page.pageSizeOptions,
        emptyBuilder: (context) => EmptyView(
          icon: Remix.apps_2_line,
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
          pageSizeOptions: SettingsService.to.page.pageSizeOptions,
          emptyBuilder: (context) => EmptyView(
            icon: Remix.apps_2_line,
            title: i18n("empty_areas_title"),
            subtitle: i18n("empty_areas_subtitle"),
            buttonText: i18n('refresh'),
            onButtonPressed: () => widget.controller.refreshData(),
          ),
          contentBuilder: (context, displayList, scrollController) {
            return const SizedBox.shrink();
          },
        );
      }

      return Column(
        children: [
          ScrollableTabBar(
            key: const ValueKey('area-category-tabs'),
            controller: _tabController,
            // A tap is committed intent, unlike an unfinished horizontal drag.
            // Publish it before a refresh response can remap category indices.
            onTap: widget.controller.selectCategory,
            isScrollable: true,
            physics: const PureLiveBoundedScrollPhysics(),
            tabs: categoriesList.map((e) => Tab(text: e.name)).toList(),
          ),
          Expanded(
            child: BasePageView<AreasListController, LiveArea>(
              controller: widget.controller,
              // An empty category must not dispose the surrounding horizontal pages.
              preserveContentWhenEmpty: true,
              enableRefresh: true,
              enableLoadMore: true,
              customMobileBottomPadding: 85,
              customDesktopBottomPadding: 135,
              showScrollToTopBtn: SettingsService.to.page.showScrollToTopBtn.v,
              showPageSizeSelector: SettingsService.to.page.showPageSizeSelector.v,
              pageSizeOptions: SettingsService.to.page.pageSizeOptions,
              emptyBuilder: (context) => EmptyView(
                icon: Remix.apps_2_line,
                title: i18n("empty_areas_title"),
                subtitle: i18n("empty_areas_subtitle"),
              ),
              contentBuilder: (context, displayList, _) {
                final activeIndex = widget.controller.tabIndex.value;
                return TabBarView(
                  controller: _tabController,
                  physics: const PureLiveBoundedScrollPhysics(),
                  children: categoriesList.asMap().entries.map((entry) {
                    final category = entry.value;
                    return Builder(
                      key: ValueKey('area_page_${category.id}'),
                      builder: (context) {
                        final isCurrentTab = activeIndex == entry.key;
                        final finalData = widget.controller.usesDesktopPagination && isCurrentTab
                            ? displayList
                            : category.children;
                        if (finalData.isEmpty) {
                          return LayoutBuilder(
                            builder: (context, constraints) => SingleChildScrollView(
                              key: PageStorageKey('area_empty_${widget.tag}_${category.id}'),
                              controller: _scrollControllerFor(category.id),
                              // Inherit EasyRefresh physics, like the populated grid.
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                child: Center(
                                  child: EmptyView(
                                    icon: Remix.apps_2_line,
                                    title: i18n("empty_areas_title"),
                                    subtitle: i18n("empty_areas_subtitle"),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return buildFlattenAreasView(
                          finalData,
                          _scrollControllerFor(category.id),
                          scrollKey: PageStorageKey('area_grid_${widget.tag}_${category.id}'),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  Widget buildFlattenAreasView(List<LiveArea> childrenList, ScrollController scrollController, {Key? scrollKey}) {
    return LayoutBuilder(
      builder: (context, constraint) {
        final width = constraint.maxWidth;
        final crossAxisCount = width > 1280 ? 9 : (width > 960 ? 7 : (width > 640 ? 5 : 3));
        final spacing = SettingsService.to.theme.crossAxisSpacing.v;
        final itemWidth = (width - 12 - spacing * (crossAxisCount - 1)) / crossAxisCount;

        return GridView.builder(
          key: scrollKey,
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 80),
          controller: scrollController,
          scrollCacheExtent: ScrollCacheExtent.pixels(width > 680 ? 480 : 320),
          addAutomaticKeepAlives: false,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: SettingsService.to.theme.mainAxisSpacing.v,
            mainAxisExtent: areaCardGridMainAxisExtent(context, itemWidth),
          ),
          itemCount: childrenList.length,
          itemBuilder: (context, index) {
            final area = childrenList[index];
            return AreaCard(key: ValueKey('${area.platform}:${area.areaId}'), category: area);
          },
        );
      },
    );
  }
}
