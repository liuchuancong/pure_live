import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_failure.dart';
import 'package:live_sites/src/platforms/seventeenlive/seventeenlive_manifest.dart';
import 'package:live_sites/src/platforms/seventeenlive/seventeenlive_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// 17LIVE's discovery feed: the website's own Japan home page — the
/// recommendation sections the reference asked for and called its
/// recommendations.
///
/// The feed has no personal mix for an anonymous visitor: it is the same cursor
/// list as an area's rooms, so a caller that carries a cursor forward gets the
/// next rows and one that names a page number is walked there from page 1.
final class SeventeenLiveDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  SeventeenLiveDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final SeventeenLiveSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({LivePageRequest? request}) async {
    request ??= LivePageRequest();
    try {
      final page = await site.directory(page: request.page, cursor: request.cursor, pageSize: request.pageSize);
      return right(LivePage.of(items: page.rooms, hasMore: page.hasMore, nextCursor: page.nextCursor));
    } on SeventeenLiveFailure catch (failure) {
      return left(failure.toLiveSiteError(seventeenliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: seventeenliveSiteId, message: '$error', cause: error));
    }
  }
}
