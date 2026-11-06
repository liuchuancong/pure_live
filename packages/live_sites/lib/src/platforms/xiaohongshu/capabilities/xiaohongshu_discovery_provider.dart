import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_failure.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_manifest.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Xiaohongshu's discovery feed: the visitor directory's unfiltered listing
/// (the platform's own 热门 square) when a guest is injected, and always
/// empty without one (3.x showed its directory notice instead — no public
/// list is reachable anonymously).
///
/// A caller that carries [LivePageRequest.cursor] forward costs one request
/// per page; a caller that names only a page number is walked there by the
/// site's cursor replay. A page below 1 is a caller error, never an empty
/// page.
final class XiaohongshuDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  XiaohongshuDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final XiaohongshuSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({LivePageRequest? request}) async {
    request ??= LivePageRequest();
    try {
      final page = await site.directory(request.page, cursor: request.cursor);
      return right(LivePage.of(items: page.rooms, hasMore: page.hasMore, nextCursor: page.nextCursor));
    } on XiaohongshuFailure catch (failure) {
      return left(failure.toLiveSiteError(xiaohongshuSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: xiaohongshuSiteId, message: '$error', cause: error));
    }
  }
}
