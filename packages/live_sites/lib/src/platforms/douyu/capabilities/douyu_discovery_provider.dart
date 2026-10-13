import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/douyu/api/douyu_endpoints.dart';
import 'package:live_sites/src/platforms/douyu/douyu_site.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_failure.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Douyu's discovery feed: the `allpage` recommendations.
/// Douyu's discovery feed: the `allpage` recommendations.
final class DouyuDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  /// Serves [site].
  DouyuDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final DouyuSite site;

  @override
  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final page = request.page < 1 ? 1 : request.page;
      final response = await site.httpGet(DouyuEndpoints.recommend(page), headers: site.apiHeaders(''));
      final result = DouyuRoomParser.roomList(response.text, page: page, status: response.status);
      return right(LivePage(items: result.rooms, hasMore: result.hasMore));
    } on DouyuFailure catch (failure) {
      return left(failure.toLiveSiteError('douyu'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'douyu', message: '$error', cause: error));
    }
  }
}
