import 'package:pure_live/common/index.dart';

class PopularLocalReactiveController extends LocalReactivePageController<LiveRoom> {
  final Site site;
  PopularLocalReactiveController(this.site);

  @override
  Future<void> syncLocalStreamStatus(int page, int pageSize) async {
    final freshData = await site.liveSite.getRecommendRooms(page: page, pageSize: pageSize);
    updateLocalReactivePool(freshData);
  }
}

class PopularServerAllController extends ServerAllPageController<LiveRoom> {
  final Site site;
  PopularServerAllController(this.site);

  @override
  Future<List<LiveRoom>> fetchAllServerData() async {
    return await site.liveSite.getRecommendRooms(page: currentPage, pageSize: pageSize.value);
  }
}

class PopularServerFixedController extends ServerFixedPageController<LiveRoom> {
  final Site site;

  PopularServerFixedController(this.site, {required int fixedSize}) : super(fixedServerPageSize: fixedSize);

  @override
  Future<List<LiveRoom>> fetchFixedNetworkData(int bigPage, int fixedSize) async {
    return await site.liveSite.getRecommendRooms(page: bigPage, pageSize: fixedSize);
  }
}

class PopularServerRemoteController extends ServerRemotePageController<LiveRoom> {
  final Site site;
  PopularServerRemoteController(this.site);

  @override
  Future<List<LiveRoom>> fetchNetworkData(int page, int pageSize) async {
    return await site.liveSite.getRecommendRooms(page: page, pageSize: pageSize);
  }
}
