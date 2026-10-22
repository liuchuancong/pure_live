import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kick/api/kick_endpoints.dart';
import 'package:live_sites/src/platforms/kick/kick_manifest.dart';
import 'package:live_sites/src/platforms/kick/kick_site.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_failure.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Kick's discovery feed: the site-wide live directory by viewers (Kick
/// recommends no personal feed to an anonymous client; this is the busiest
/// list it gives everyone).
final class KickDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  KickDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final KickSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final page = request.page < 1 ? 1 : request.page;
      final size = request.pageSize.clamp(1, KickEndpoints.pageSize);
      final response = await site.httpGet(KickEndpoints.livestreams(page, size), headers: site.apiHeaders());
      final result = KickRoomParser.directoryPage(response.text, page: page, pageSize: size, status: response.status);
      return right(LivePage(items: result.rooms, hasMore: result.hasMore));
    } on KickFailure catch (failure) {
      return left(failure.toLiveSiteError(kickSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: kickSiteId, message: '$error', cause: error));
    }
  }
}
