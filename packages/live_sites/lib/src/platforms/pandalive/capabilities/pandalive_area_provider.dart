import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/pandalive/api/pandalive_endpoints.dart';
import 'package:live_sites/src/platforms/pandalive/pandalive_manifest.dart';
import 'package:live_sites/src/platforms/pandalive/pandalive_site.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// PandaTV's areas: the two fixed directories (公开直播 and 新人主播), and
/// the rooms under each.
///
/// The platform has no area API: the areas are the catalog's own. Another
/// area id is a caller error, never an empty page.
final class PandaliveAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  PandaliveAreaProvider({required this.site});

  /// The site this capability serves.
  final PandaliveSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async => right([
    for (final entry in PandaliveEndpoints.areas.entries)
      LiveArea.normalized(
        platform: PandaliveEndpoints.siteId,
        areaId: entry.key,
        areaName: entry.value,
        parentAreaId: PandaliveEndpoints.siteId,
        parentAreaName: PandaliveEndpoints.siteName,
      ),
  ]);

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required String areaId,
    LivePageRequest? request,
  }) async {
    request ??= LivePageRequest();
    try {
      final page = await site.directory(request.page, request.pageSize, areaId: areaId);
      return right(LivePage.of(items: page.rooms, hasMore: page.hasMore));
    } on PandaliveFailure catch (failure) {
      return left(failure.toLiveSiteError(pandaliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: pandaliveSiteId, message: '$error', cause: error));
    }
  }
}
