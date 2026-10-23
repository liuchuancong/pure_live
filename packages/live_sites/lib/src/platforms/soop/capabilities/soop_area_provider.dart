import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/soop/parsers/soop_failure.dart';
import 'package:live_sites/src/platforms/soop/soop_manifest.dart';
import 'package:live_sites/src/platforms/soop/soop_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// SOOP's areas: the one category 热门 whose children are the platform's
/// whole area list, paged natively, and the rooms under each.
///
/// The first catalog page failing fails the catalog; a later one ends it
/// with what was read, because the tail of that list holds small areas. An
/// empty area id is a caller error.
final class SoopAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  SoopAreaProvider({required this.site});

  /// The site this capability serves.
  final SoopSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async {
    try {
      return right(await site.areas());
    } on SoopFailure catch (failure) {
      return left(failure.toLiveSiteError(soopSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: soopSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required LiveArea area,
    LivePageRequest? request,
  }) async {
    request ??= LivePageRequest();
    try {
      final page = await site.areaRooms(area.areaId, page: request.page, pageSize: request.pageSize);
      return right(LivePage.of(items: page.rooms, hasMore: page.hasMore));
    } on SoopFailure catch (failure) {
      return left(failure.toLiveSiteError(soopSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: soopSiteId, message: '$error', cause: error));
    }
  }
}
