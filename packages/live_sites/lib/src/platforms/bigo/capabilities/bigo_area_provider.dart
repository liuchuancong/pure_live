import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/bigo/bigo_manifest.dart';
import 'package:live_sites/src/platforms/bigo/bigo_site.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_failure.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Bigo's areas: the one public list.
///
/// The website has no category tree — every browse is the same ~20-room
/// snapshot — so `getAreas` gives that one area without a request and
/// `getAreaRooms` is the directory page. Any other area id is a caller error.
final class BigoAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  BigoAreaProvider({required this.site});

  /// The site this capability serves.
  final BigoSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async {
    try {
      return right([BigoRoomParser.area()]);
    } on BigoFailure catch (failure) {
      return left(failure.toLiveSiteError(bigoSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: bigoSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required String areaId,
    LivePageRequest? request,
  }) async {
    request ??= LivePageRequest();
    if (!BigoRoomParser.isAreaId(areaId)) {
      return left(
        LiveSiteError.invalidArgument(siteId: bigoSiteId, message: 'area "$areaId" is not the bigo public list'),
      );
    }
    try {
      final page = request.page < 1 ? 1 : request.page;
      final result = await site.directory(page);
      return right(LivePage.of(items: result.rooms, hasMore: result.hasMore));
    } on BigoFailure catch (failure) {
      return left(failure.toLiveSiteError(bigoSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: bigoSiteId, message: '$error', cause: error));
    }
  }
}
