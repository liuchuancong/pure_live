import 'package:pure_live/common/index.dart';

/// Applies the same audience policy used by favourites, search and room
/// pickers to a platform's popular list. Server recommendation order is still
/// useful as the fetched candidate pool, but every visible page is normalized
/// to descending values so adapters cannot silently drift to a different
/// field or return an unstable order.
List<LiveRoom> rankPopularRoomsByAudience(
  Iterable<LiveRoom> rooms, {
  required bool preferRealOnline,
  required Iterable<String> realOnlinePlatforms,
}) {
  final enabledPlatforms = realOnlinePlatforms.map((platform) => platform.trim().toLowerCase()).toSet();
  final ranked = rooms.toList(growable: false);
  ranked.sort(
    (left, right) => LiveRoom.compareAudienceRanking(
      left,
      right,
      preferRealOnline: preferRealOnline,
      platformEnabled: (platform) => enabledPlatforms.contains(platform?.trim().toLowerCase()),
    ),
  );
  return ranked;
}

List<LiveRoom> _rankForCurrentSettings(List<LiveRoom> rooms) {
  final app = SettingsService.to.app;
  return rankPopularRoomsByAudience(
    rooms,
    preferRealOnline: app.preferRealOnlineCounts.v,
    realOnlinePlatforms: app.realOnlinePlatforms,
  );
}

class PopularLocalReactiveController extends LocalReactivePageController<LiveRoom> {
  final Site site;
  PopularLocalReactiveController(this.site) {
    onExternalRefresh = () async {
      await loadData();
    };
  }

  @override
  Future<void> loadData() async {
    loadding.value = true;
    pageEmpty.value = false;
    try {
      final rooms = await getLocalRawData();
      updateLocalReactivePool(rooms);
    } catch (e) {
      handleError(e, showPageError: list.isEmpty);
      pageEmpty.value = list.isEmpty;
      finishRefreshControllers(IndicatorResult.fail);
    } finally {
      loadding.value = false;
    }
  }

  Future<List<LiveRoom>> getLocalRawData() async {
    final rooms = await site.liveSite.getRecommendRooms(page: 1, pageSize: pageSize.value);
    return site.id == Sites.iptvSite ? rooms : _rankForCurrentSettings(rooms);
  }

  Future<List<LiveRoom>> refreshNetworkStatus(List<LiveRoom> currentPool, int page, int pageSize) async {
    try {
      final rooms = await site.liveSite.getRecommendRooms(page: page, pageSize: pageSize);
      return site.id == Sites.iptvSite ? rooms : _rankForCurrentSettings(rooms);
    } catch (e) {
      if (e.toString().contains("NoSuchMethodError") && e.toString().contains("'[]'")) {
        throw Exception("loginRequired");
      }
      rethrow;
    }
  }
}

class PopularServerAllController extends ServerAllPageController<LiveRoom> {
  final Site site;
  PopularServerAllController(this.site);

  @override
  Future<List<LiveRoom>> fetchAllServerData() async {
    return _rankForCurrentSettings(await site.liveSite.getRecommendRooms(page: currentPage, pageSize: pageSize.value));
  }
}

class PopularServerFixedController extends ServerFixedPageController<LiveRoom> {
  final Site site;

  PopularServerFixedController(this.site, {required int fixedSize}) : super(fixedServerPageSize: fixedSize);

  @override
  Future<List<LiveRoom>> fetchFixedNetworkData(int bigPage, int fixedSize) async {
    return _rankForCurrentSettings(await site.liveSite.getRecommendRooms(page: bigPage, pageSize: fixedSize));
  }
}

class PopularServerRemoteController extends ServerRemotePageController<LiveRoom> {
  final Site site;
  PopularServerRemoteController(this.site);

  @override
  Future<List<LiveRoom>> fetchNetworkData(int page, int pageSize) async {
    return _rankForCurrentSettings(await site.liveSite.getRecommendRooms(page: page, pageSize: pageSize));
  }
}
