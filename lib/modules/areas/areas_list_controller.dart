import 'dart:convert';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/plugins/area_pic_mapper.dart';

class AreasListController extends ServerAllPageController<AppLiveCategory> {
  final Site site;
  final tabIndex = 0.obs;

  AreasListController(this.site);

  @override
  Future<List<AppLiveCategory>> fetchAllServerData() async {
    var result = await site.liveSite.getCategores(currentPage, pageSize.value);
    var channels = result.map((e) => AppLiveCategory.fromLiveCategory(e)).toList();
    AreaPicMapper.updateAreaListMaps(channels);
    return channels;
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
  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = id;
    json['name'] = name;
    json['children'] = children.map((LiveArea e) => jsonEncode(e.toJson())).toList();
    return json;
  }
}
