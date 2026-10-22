import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kuaishou/api/kuaishou_endpoints.dart';
import 'package:live_sites/src/platforms/kuaishou/kuaishou_manifest.dart';
import 'package:live_sites/src/platforms/kuaishou/kuaishou_site.dart';
import 'package:live_sites/src/platforms/kuaishou/parsers/kuaishou_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Kuaishou's areas: the eight fixed top categories, each walked to its last
/// `category/data` page, and one `gameboard`/`non-gameboard` page per area.
///
/// Areas are returned flat, each carrying its top category as parent; the page
/// cursor and the earlier-page dedup live in the site.
final class KuaishouAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  KuaishouAreaProvider({required this.site});

  /// The site this capability serves.
  final KuaishouSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async {
    try {
      final areas = <LiveArea>[];
      for (final top in KuaishouEndpoints.topCategories) {
        areas.addAll(await site.categoryAreas(top.id, top.name));
      }
      return right(areas);
    } on KuaishouFailure catch (failure) {
      return left(failure.toLiveSiteError(kuaishouSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: kuaishouSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required String areaId,
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final page = request.page < 1 ? 1 : request.page;
      final result = await site.areaPage(areaId.trim(), page);
      return right(LivePage(items: result.rooms, hasMore: result.hasMore));
    } on KuaishouFailure catch (failure) {
      return left(failure.toLiveSiteError(kuaishouSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: kuaishouSiteId, message: '$error', cause: error));
    }
  }
}
