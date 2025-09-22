import 'package:get/get.dart';
import 'package:pure_live/common/base/base_controller.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/plugins/cache_to_file.dart';

class AreasListController extends BasePageController<LiveCategory> {
  final Site site;
  final tabIndex = 0.obs;
  AreasListController(this.site);

  @override
  Future<List<LiveCategory>> getData(int page, int pageSize) async {
    var cacheKey = "${site.id}_${tabIndex.value}_${page}_$pageSize";
    if(await CustomCache.instance.isExistCache(cacheKey) && site.cacheCategory) {
      CoreLog.d("cacheCategory: ${site.name}");
      var list = (await CustomCache.instance.getCache<List>(cacheKey))!;
      var rs = list.map((e) => LiveCategory.fromJson(e)).toList();
      return rs;
    }
    var result = await site.liveSite.getCategores(page, pageSize);
    // var list = result.map((e) => AppLiveCategory.fromLiveCategory(e)).toList();
    var list = result.toList();
    if(result.isEmpty || site.id == Sites.iptvSite) {
      return list;
    }
    await CustomCache.instance.setCache(cacheKey, list);
    return list;
  }
}

class AppLiveCategory extends LiveCategory {
  var showAll = false.obs;
  AppLiveCategory({required super.id, required super.name, required super.children}) {
    showAll.value = children.length < 19;
  }

  List<LiveArea> get take15 => children.take(15).toList();

  factory AppLiveCategory.fromLiveCategory(LiveCategory item) {
    return AppLiveCategory(children: item.children, id: item.id, name: item.name);
  }

}
