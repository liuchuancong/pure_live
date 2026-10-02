import 'dart:convert';

import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/models/live_category.dart';
import 'package:pure_live/domains/live/presentation/areas/area_display_config.dart';
import 'package:pure_live/domains/live/presentation/areas/area_pic_mapper.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';

class AreasListController extends ServerAllPageController<LiveArea> {
  final Site site;
  final tabIndex = 0.obs;

  final categories = <AppLiveCategory>[].obs;
  final Map<String, List<LiveArea>> _serverRawBackup = {};

  List<LiveArea> _flattenRawAllData = [];

  /// Whether this platform's directory renders as one flat grid.
  ///
  /// The flag is decided by the catalogue the server just returned rather than
  /// by the previous one: the "a single top-level category flattens by itself"
  /// rule can only be evaluated against fresh data.
  late bool _flatten = isFlatAreaSite(site.id);

  bool get isFlatten => _flatten;

  @override
  bool get showInlineError => site.id == Sites.ccSite;

  @override
  int get localItemCount => _getCurrentTabAllChildren().length;

  AreasListController(this.site);

  @override
  Future<List<LiveArea>> fetchAllServerData() async {
    if (isClosed) return [];
    var result = await site.liveSite.getCategores(1, 1000);
    if (isClosed) return [];
    // Read the latest selection after the request; a tab click while loading
    // belongs to the user, not to the request's earlier snapshot.
    final selectedId = tabIndex.value >= 0 && tabIndex.value < categories.length ? categories[tabIndex.value].id : null;
    var channels = result.map((e) => AppLiveCategory.fromLiveCategory(e)).toList();
    AreaPicMapper.updateAreaListMaps(channels);

    // A refreshed taxonomy may remove or reorder a parent (for example CC's
    // four legacy tabs becoming live categories plus official entry points).
    // Keep identity where possible; an obsolete index must not hide valid rows.
    final selectedIndex = channels.indexWhere((category) => category.id == selectedId);
    tabIndex.value = selectedIndex < 0 ? 0 : selectedIndex;

    _serverRawBackup.clear();

    _flatten = shouldFlattenCategories(site.id, channels);
    if (_flatten) {
      _flattenRawAllData = flattenCategories(channels);
      categories.assignAll(channels);
      return _flattenRawAllData;
    } else {
      for (var cat in channels) {
        _serverRawBackup[cat.id] = List.from(cat.children);
      }
      categories.assignAll(channels);
      return _getCurrentTabAllChildren();
    }
  }

  List<LiveArea> _getCurrentTabAllChildren() {
    if (isFlatten) {
      return _flattenRawAllData;
    }
    int activeIndex = tabIndex.value;
    if (activeIndex >= categories.length || categories.isEmpty) {
      return [];
    }
    final catId = categories[activeIndex].id;
    return _serverRawBackup[catId] ?? [];
  }

  /// Switches a category from the catalogue already returned by the server.
  ///
  /// Re-entering [loadData] for every settled horizontal swipe needlessly
  /// passed through the asynchronous loading pipeline and published extra
  /// reactive frames. Category contents are local at this point, so update the
  /// active slice synchronously and keep the finger-to-page transition linear.
  void selectCategory(int index) {
    if (isClosed || isFlatten || index < 0 || index >= categories.length || tabIndex.value == index) return;
    tabIndex.value = index;
    currentPage = 1;
    processLocalPaging(finishRefresh: !hasActiveLoad);
  }

  @override
  void processLocalPaging({bool finishRefresh = true}) {
    if (isClosed) return;
    // Selecting cached rows is not completion of a pending server snapshot.
    void finish(IndicatorResult result) {
      if (finishRefresh) finishRefreshControllers(result);
    }

    if (isFlatten) {
      final allItems = _flattenRawAllData;
      totalCount.value = allItems.length;

      if (allItems.isEmpty) {
        list.clear();
        canLoadMore.value = false;
        pageEmpty.value = true;
        finish(IndicatorResult.noMore);
        return;
      }

      if (usesDesktopPagination) {
        int startIndex = (currentPage - 1) * pageSize.value;
        if (startIndex >= allItems.length) {
          currentPage = 1;
          startIndex = 0;
        }

        int endIndex = startIndex + pageSize.value;
        if (endIndex > allItems.length) endIndex = allItems.length;

        final newData = allItems.sublist(startIndex, endIndex);
        list.assignAll(newData);
        canLoadMore.value = endIndex < allItems.length;
        pageEmpty.value = list.isEmpty;
        finish(canLoadMore.value ? IndicatorResult.success : IndicatorResult.noMore);
        if (currentPage == 1) {
          scrollToTopImmediate();
        }
      } else {
        list.assignAll(allItems);
        canLoadMore.value = false;
        pageEmpty.value = list.isEmpty;
        finish(IndicatorResult.noMore);
      }
      return;
    }

    int activeIndex = tabIndex.value;
    if (categories.isEmpty || activeIndex >= categories.length) {
      list.clear();
      canLoadMore.value = false;
      pageEmpty.value = true;
      finish(IndicatorResult.noMore);
      return;
    }

    final currentCategory = categories[activeIndex];
    final allItems = _getCurrentTabAllChildren();
    totalCount.value = allItems.length;

    if (allItems.isEmpty) {
      list.clear();
      canLoadMore.value = false;
      pageEmpty.value = true;
      if (usesDesktopPagination && currentCategory.children.isNotEmpty) {
        currentCategory.children.clear();
        categories.refresh();
      }
      finish(IndicatorResult.noMore);
      return;
    }

    if (usesDesktopPagination) {
      int startIndex = (currentPage - 1) * pageSize.value;
      if (startIndex >= allItems.length) {
        currentPage = 1;
        startIndex = 0;
      }

      int endIndex = startIndex + pageSize.value;
      if (endIndex > allItems.length) endIndex = allItems.length;

      final newData = allItems.sublist(startIndex, endIndex);
      list.assignAll(newData);
      // This is an owned plain List, not RxList: the vendored assignAll
      // extension appends to plain lists instead of replacing their contents.
      currentCategory.children
        ..clear()
        ..addAll(newData);
      canLoadMore.value = endIndex < allItems.length;
      pageEmpty.value = list.isEmpty;
      if (currentPage == 1) {
        scrollToTopImmediate();
      }
      finish(canLoadMore.value ? IndicatorResult.success : IndicatorResult.noMore);
      categories.refresh();
    } else {
      list.assignAll(allItems);
      canLoadMore.value = false;
      pageEmpty.value = list.isEmpty;
      finish(IndicatorResult.noMore);
    }
  }
}

class AppLiveCategory extends LiveCategory {
  // UI pagination mutates this list. Never alias an adapter's cached,
  // fixed-size or unmodifiable catalogue.
  AppLiveCategory({required super.id, required super.name, required List<LiveArea> children})
    : super(children: List<LiveArea>.of(children));

  factory AppLiveCategory.fromLiveCategory(LiveCategory item) {
    return AppLiveCategory(children: item.children, id: item.id, name: item.name);
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = id;
    json['name'] = name;
    json['children'] = children.map((LiveArea e) => jsonEncode(e.toJson())).toList();
    return json;
  }
}
