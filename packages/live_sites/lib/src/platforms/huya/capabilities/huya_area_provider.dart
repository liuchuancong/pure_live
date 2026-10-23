import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/huya/api/huya_endpoints.dart';
import 'package:live_sites/src/platforms/huya/huya_manifest.dart';
import 'package:live_sites/src/platforms/huya/huya_site.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_failure.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Huya's areas: the four fixed top-level categories (网游/单机/娱乐/手游) with
/// their areas, and one `getLiveListByPage` page per area.
final class HuyaAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  HuyaAreaProvider({required this.site});

  /// The site this capability serves.
  final HuyaSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async {
    try {
      final fetched = await Future.wait([
        for (final top in huyaTopCategories)
          site
              .httpGet(HuyaEndpoints.areaList(top.id), headers: const {'user-agent': HuyaEndpoints.userAgent})
              .then((response) => (top: top, response: response)),
      ]);
      return right([
        for (final (:top, :response) in fetched)
          ...HuyaRoomParser.areas(response.text, categoryId: top.id, categoryName: top.name, status: response.status),
      ]);
    } on HuyaFailure catch (failure) {
      return left(failure.toLiveSiteError(huyaSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: huyaSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required LiveArea area,
    LivePageRequest? request,
  }) async {
    request ??= LivePageRequest();
    try {
      final page = request.page < 1 ? 1 : request.page;
      final response = await site.httpGet(
        HuyaEndpoints.liveList(page, gameId: area.areaId.trim()),
        headers: site.webHeaders(),
      );
      final result = HuyaRoomParser.roomList(response.text, page: page, status: response.status);
      return right(LivePage.of(items: result.rooms, hasMore: result.hasMore));
    } on HuyaFailure catch (failure) {
      return left(failure.toLiveSiteError(huyaSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: huyaSiteId, message: '$error', cause: error));
    }
  }
}
