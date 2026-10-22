import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/missevan/missevan_manifest.dart';
import 'package:live_sites/src/platforms/missevan/missevan_site.dart';
import 'package:live_sites/src/platforms/missevan/parsers/missevan_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Missevan's recommendations: the native pages of `chatroom/open/list`,
/// every live room of a page, each once, paged by number.
///
/// The platform has no personalized feed; the recommendations are what the
/// site shows.
final class MissevanDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  MissevanDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final MissevanSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final page = await site.directory(request.page, pageSize: request.pageSize);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on MissevanFailure catch (failure) {
      return left(failure.toLiveSiteError(missevanSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: missevanSiteId, message: '$error', cause: error));
    }
  }
}
