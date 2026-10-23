import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_failure.dart';
import 'package:live_sites/src/platforms/twitch/twitch_manifest.dart';
import 'package:live_sites/src/platforms/twitch/twitch_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Twitch's discovery feed: the busiest live streams of the whole site.
///
/// Twitch's web client personalises its home shelf through an integrity token
/// an anonymous client never gets, so this is the site-wide ranking — the same
/// list the 3.x recommendations showed — filtered only by the broadcast
/// languages the caller chose.
final class TwitchDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  TwitchDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final TwitchSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({LivePageRequest? request}) async {
    request ??= LivePageRequest();
    try {
      final result = await site.recommend(request.page, request.pageSize);
      return right(LivePage.of(items: result.rooms, hasMore: result.hasMore));
    } on TwitchFailure catch (failure) {
      return left(failure.toLiveSiteError(twitchSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: twitchSiteId, message: '$error', cause: error));
    }
  }
}
