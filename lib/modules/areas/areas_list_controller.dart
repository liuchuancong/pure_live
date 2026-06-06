import 'dart:convert';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/plugins/area_pic_mapper.dart';
import 'package:pure_live/common/global/platform_utils.dart';

class AreasListController extends ServerAllPageController<LiveArea> {
  final Site site;
  final tabIndex = 0.obs;

  final categories = <AppLiveCategory>[].obs;
  final Map<String, List<LiveArea>> _serverRawBackup = {};
  final Map<String, List<LiveArea>> _mobileAppendCache = {};

  List<LiveArea> _flattenRawAllData = [];

  bool get isFlatten => site.id == Sites.douyinSite;

  AreasListController(this.site);

  @override
  Future<List<LiveArea>> fetchAllServerData() async {
    var result = await site.liveSite.getCategores(1, 1000);
    var channels = result.map((e) => AppLiveCategory.fromLiveCategory(e)).toList();
    AreaPicMapper.updateAreaListMaps(channels);

    _serverRawBackup.clear();
    _mobileAppendCache.clear();

    if (isFlatten) {
      _flattenRawAllData = channels.expand((e) => e.children).toList();
      categories.assignAll(channels);
      return _flattenRawAllData;
    } else {
      for (var cat in channels) {
        _serverRawBackup[cat.id] = List.from(cat.children);
        _mobileAppendCache[cat.id] = [];
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

  @override
  void processLocalPaging() {
    if (isFlatten) {
      final allItems = _flattenRawAllData;
      totalCount.value = allItems.length;

      if (allItems.isEmpty) {
        list.clear();
        canLoadMore.value = false;
        pageEmpty.value = true;
        finishRefreshControllers(IndicatorResult.noMore);
        return;
      }

      int startIndex = (currentPage - 1) * pageSize.value;
      if (startIndex >= allItems.length) {
        currentPage = 1;
        startIndex = 0;
      }

      int endIndex = startIndex + pageSize.value;
      if (endIndex > allItems.length) endIndex = allItems.length;

      final newData = allItems.sublist(startIndex, endIndex);

      if (PlatformUtils.isDesktop) {
        list.assignAll(newData);
      } else {
        if (currentPage == 1) {
          list.assignAll(newData);
        } else {
          list.addAll(newData);
        }
      }

      canLoadMore.value = endIndex < allItems.length;
      pageEmpty.value = list.isEmpty;
      finishRefreshControllers(canLoadMore.value ? IndicatorResult.success : IndicatorResult.noMore);

      if (currentPage == 1) {
        scrollToTopImmediate();
      }
      return;
    }

    int activeIndex = tabIndex.value;

    // 💡 核心修复：当 categories 为空或者越界时，证明接口数据为空，必须走标准空状态清理机制，绝不能直接无责任 return
    if (categories.isEmpty || activeIndex >= categories.length) {
      list.clear();
      canLoadMore.value = false;
      pageEmpty.value = true;
      categories.refresh();
      finishRefreshControllers(IndicatorResult.noMore);
      return;
    }

    final currentCategory = categories[activeIndex];
    final allItems = _getCurrentTabAllChildren();
    totalCount.value = allItems.length;

    if (allItems.isEmpty) {
      currentCategory.children.clear();
      list.clear();
      canLoadMore.value = false;
      pageEmpty.value = true;
      categories.refresh();
      finishRefreshControllers(IndicatorResult.noMore);
      return;
    }

    int startIndex = (currentPage - 1) * pageSize.value;
    if (startIndex >= allItems.length) {
      currentPage = 1;
      startIndex = 0;
    }

    int endIndex = startIndex + pageSize.value;
    if (endIndex > allItems.length) endIndex = allItems.length;

    final newData = allItems.sublist(startIndex, endIndex);

    if (PlatformUtils.isDesktop) {
      list.assignAll(newData);
      currentCategory.children.assignAll(newData);
    } else {
      if (currentPage == 1) {
        _mobileAppendCache[currentCategory.id] = List.from(newData);
      } else {
        _mobileAppendCache[currentCategory.id]?.addAll(newData);
      }
      final currentCache = _mobileAppendCache[currentCategory.id] ?? [];
      list.assignAll(currentCache);
      currentCategory.children.assignAll(currentCache);
    }

    canLoadMore.value = endIndex < allItems.length;
    pageEmpty.value = list.isEmpty;
    categories.refresh();

    finishRefreshControllers(canLoadMore.value ? IndicatorResult.success : IndicatorResult.noMore);

    if (currentPage == 1) {
      scrollToTopImmediate();
    }
  }
}

class AppLiveCategory extends LiveCategory {
  AppLiveCategory({required super.id, required super.name, required super.children});

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
