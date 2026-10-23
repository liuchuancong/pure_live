import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/jdlive/api/jdlive_endpoints.dart';
import 'package:live_sites/src/platforms/jdlive/jdlive_manifest.dart';
import 'package:live_sites/src/platforms/jdlive/jdlive_site.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_failure.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// JD Live's areas: the one featured list, and its rooms.
///
/// The site has no catalog request: the area is the platform's own. Another
/// area id is a caller error, never an empty page.
final class JdliveAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  JdliveAreaProvider({required this.site});

  /// The site this capability serves.
  final JdliveSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async => right([JdliveRoomParser.area()]);

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required String areaId,
    LivePageRequest? request,
  }) async {
    request ??= LivePageRequest();
    if (areaId != JdliveEndpoints.areaId) {
      return left(
        LiveSiteError.invalidArgument(siteId: jdliveSiteId, message: 'area "$areaId" is not the JD Live featured list'),
      );
    }
    try {
      final page = await site.recommend(request.page, request.pageSize);
      return right(LivePage.of(items: page.rooms, hasMore: page.hasMore));
    } on JdliveFailure catch (failure) {
      return left(failure.toLiveSiteError(jdliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: jdliveSiteId, message: '$error', cause: error));
    }
  }
}
