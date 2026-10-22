import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_failure.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_parser.dart';
import 'package:live_sites/src/platforms/showroom/showroom_manifest.dart';
import 'package:live_sites/src/platforms/showroom/showroom_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// SHOWROOM's areas: the snapshot's genres under the one category SHOWROOM,
/// and the rooms under each.
///
/// There is no area API of its own: the areas and their rooms are slices of
/// the `live/onlives` snapshot, 30 rows a page. A genre number is an area id;
/// anything else is a caller error, never an empty page, and a genre the
/// snapshot no longer has is not-found.
final class ShowroomAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  ShowroomAreaProvider({required this.site});

  /// The site this capability serves.
  final ShowroomSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async {
    try {
      return right(ShowroomParser.areas(await site.snapshotFor()));
    } on ShowroomFailure catch (failure) {
      return left(failure.toLiveSiteError(showroomSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: showroomSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required String areaId,
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      // The platform pages genres itself (30 rooms a page, of one snapshot);
      // a caller's page size does not reshape the slice.
      final page = await site.directory(request.page, areaId: areaId);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on ShowroomFailure catch (failure) {
      return left(failure.toLiveSiteError(showroomSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: showroomSiteId, message: '$error', cause: error));
    }
  }
}
