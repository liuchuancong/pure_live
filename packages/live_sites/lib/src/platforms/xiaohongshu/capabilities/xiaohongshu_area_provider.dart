import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_failure.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_manifest.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Xiaohongshu's areas: the platform's own category response, returned flat
/// with the reference's one `live`/小红书 group as each row's parent.
///
/// Without a visitor bootstrap there are no areas — the platform names them
/// only to its signed visitor requests, so the list is empty rather than
/// guessed. An area's rooms are the same guest feed as the site-wide
/// listing, asked with the category id the catalog named; an area of another
/// platform, or one whose id the platform could not have named, is a caller
/// error, never a guessed path.
final class XiaohongshuAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  XiaohongshuAreaProvider({required this.site});

  /// The site this capability serves.
  final XiaohongshuSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async {
    try {
      return right(await site.categories());
    } on XiaohongshuFailure catch (failure) {
      return left(failure.toLiveSiteError(xiaohongshuSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: xiaohongshuSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required LiveArea area,
    LivePageRequest? request,
  }) async {
    request ??= LivePageRequest();
    try {
      final page = await site.directory(request.page, cursor: request.cursor, category: area);
      return right(LivePage.of(items: page.rooms, hasMore: page.hasMore, nextCursor: page.nextCursor));
    } on XiaohongshuFailure catch (failure) {
      return left(failure.toLiveSiteError(xiaohongshuSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: xiaohongshuSiteId, message: '$error', cause: error));
    }
  }
}
