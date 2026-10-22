import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
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

/// Huya's discovery feed: the `getLiveListByPage` recommendations (no
/// `gameId`), which add Origin and Referer.
final class HuyaDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  HuyaDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final HuyaSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final page = request.page < 1 ? 1 : request.page;
      final response = await site.httpGet(
        HuyaEndpoints.liveList(page),
        headers: {...site.webHeaders(), 'origin': HuyaEndpoints.origin, 'referer': '${HuyaEndpoints.origin}/'},
      );
      final result = HuyaRoomParser.roomList(response.text, page: page, status: response.status);
      return right(LivePage(items: result.rooms, hasMore: result.hasMore));
    } on HuyaFailure catch (failure) {
      return left(failure.toLiveSiteError(huyaSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: huyaSiteId, message: '$error', cause: error));
    }
  }
}
