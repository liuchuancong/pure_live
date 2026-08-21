import 'dart:async';

import 'package:remixicon/remixicon.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:pure_live/common/index.dart';
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
    widget.controller.bindActiveScrollController(_scrollControllerFor(list[initialIndex].id));

    if (mounted) setState(() {});
  }

  void _handleInternalTabChange() {
    if (_tabController == null || _tabController!.indexIsChanging) return;
    final animationValue = _tabController!.animation?.value ?? _tabController!.index.toDouble();
    if ((animationValue - _tabController!.index).abs() > 0.001) return;
    if (widget.controller.tabIndex.value != _tabController!.index) {
      // Category data is already local. Commit only after the horizontal
      // gesture settles, and bind the destination's dedicated controller so
      // offsets never leak between PageView children.
      final target = _tabController!.index;
      final categories = widget.controller.categories;
      if (target >= 0 && target < categories.length) {
        widget.controller.bindActiveScrollController(_scrollControllerFor(categories[target].id));
      }
      widget.controller.tabIndex.value = _tabController!.index;
      widget.controller.currentPage = 1;
      unawaited(widget.controller.loadData());
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
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: categoriesList.map((e) => Tab(text: e.name)).toList(),
          ),
          Expanded(
            child: BasePageView<AreasListController, LiveArea>(
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
              contentBuilder: (context, displayList, _) {
                final activeIndex = widget.controller.tabIndex.value;
                return TabBarView(
                  controller: _tabController,
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
                          return EmptyView(
                            icon: Remix.apps_2_line,
                            title: i18n("empty_areas_title"),
                            subtitle: i18n("empty_areas_subtitle"),
                          );
                        }
                        return buildFlattenAreasView(finalData, _scrollControllerFor(category.id));
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

  Widget buildFlattenAreasView(List<LiveArea> childrenList, ScrollController scrollController) {
    return LayoutBuilder(
      builder: (context, constraint) {
        final width = constraint.maxWidth;
        final crossAxisCount = width > 1280 ? 9 : (width > 960 ? 7 : (width > 640 ? 5 : 3));
        final spacing = SettingsService.to.theme.crossAxisSpacing.v;
        final itemWidth = (width - 12 - spacing * (crossAxisCount - 1)) / crossAxisCount;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 80),
          controller: scrollController,
          scrollCacheExtent: ScrollCacheExtent.pixels(width > 680 ? 480 : 320),
          addAutomaticKeepAlives: false,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: SettingsService.to.theme.mainAxisSpacing.v,
            mainAxisExtent: itemWidth + 72,
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
