import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_failure.dart';
import 'package:live_sites/src/platforms/youtube/youtube_manifest.dart';
import 'package:live_sites/src/platforms/youtube/youtube_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// YouTube's discovery feed: the Live hub (`youtube.com/live`, browse id
/// `UC4R8DWoMoI7CAwX8_LjQHig`).
///
/// One page is fetched and answered; the hub is treated as a single snapshot,
/// so `hasMore` is false.
final class YoutubeDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  YoutubeDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final YoutubeSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      if (request.page > 1) return right(const LivePage(items: [], hasMore: false));
      final hub = await site.hub();
      return right(LivePage(items: hub.rooms, hasMore: false));
    } on YouTubeFailure catch (failure) {
      return left(failure.toLiveSiteError(youtubeSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: youtubeSiteId, message: '$error', cause: error));
    }
  }
}
