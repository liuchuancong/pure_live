import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/douyu/api/douyu_endpoints.dart';
import 'package:live_sites/src/platforms/douyu/douyu_manifest.dart';
import 'package:live_sites/src/platforms/douyu/douyu_site.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_failure.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Douyu's areas: the category tree and one `mixList` page per area.
/// Douyu's areas: the category tree and one `mixList` page per area.
final class DouyuAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  /// Serves [site].
  DouyuAreaProvider({required this.site});

  /// The site this capability serves.
  final DouyuSite site;

  @override
  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async {
    try {
      final response = await site.httpGet(DouyuEndpoints.cateList(), headers: {'user-agent': DouyuEndpoints.userAgent});
      return right(DouyuRoomParser.areas(response.text, status: response.status));
    } on DouyuFailure catch (failure) {
      return left(failure.toLiveSiteError(douyuSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: douyuSiteId, message: '$error', cause: error));
    }
  }

  @override
  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required String areaId,
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final page = request.page < 1 ? 1 : request.page;
      final response = await site.httpGet(DouyuEndpoints.mixList(areaId.trim(), page), headers: site.apiHeaders(''));
      final result = DouyuRoomParser.roomList(response.text, page: page, status: response.status);
      return right(LivePage(items: result.rooms, hasMore: result.hasMore));
    } on DouyuFailure catch (failure) {
      return left(failure.toLiveSiteError(douyuSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: douyuSiteId, message: '$error', cause: error));
    }
  }
}
