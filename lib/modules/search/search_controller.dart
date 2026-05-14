import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';

class SearchController extends GetxController with GetSingleTickerProviderStateMixin {
  late TabController tabController;
  var index = 0.obs;
  SearchController() {
    tabController = TabController(length: Sites().availableSites().length, vsync: this);
    tabController.addListener(() {
      index.value = tabController.index;
    });
  }

  TextEditingController searchController = TextEditingController();
  String buildSearchUrl(String platform, String keyword) {
    final q = Uri.encodeComponent(keyword);
    switch (platform) {
      case Sites.ccSite:
        return "https://cc.163.com/search/all/?query=$q&only=all";
      case Sites.kuaishouSite:
        return "https://live.kuaishou.com/search?keyword=$q";
      case Sites.huyaSite:
        return "https://www.huya.com/search?hsk=$q";
      case Sites.bilibiliSite:
        return "https://search.bilibili.com/live?keyword=$q&from_source=webtop_search&spm_id_from=444.7&search_source=3";
      case Sites.douyuSite:
        return "https://www.douyu.com/search?kw=$q&dyshid=0-ed88b042da9bbc4cf4abc97500021601";
      case Sites.douyinSite:
        return "https://www.douyin.com/search/$q?type=live";
      default:
        return "https://www.baidu.com/s?wd=$q&rsv_spt=1&rsv_iqid=0x84b83a1e077a0c1a&issp=1&f=8&rsv_bp=1&rsv_idx=2&ie=utf-8&tn=baiduhome_pg&rsv_dl=tb_click&rsv_enter=1&rsv_sug3=3&rsv_sug1=2&rsv_sug7=100&rsv_btype=i&prefixsug=12&rsp=0&inputT=1112&rsv_sug4=1287";
    }
  }

  void doSearch() {
    if (searchController.text.isEmpty) {
      ToastUtil.show('请输入关键字');
      return;
    }
    final site = Sites().availableSites()[index.value];
    String url = buildSearchUrl(site.id, searchController.text);
    Get.toNamed(RoutePath.kWebSearch, arguments: url);
  }
}
