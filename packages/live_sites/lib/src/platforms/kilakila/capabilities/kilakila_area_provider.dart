import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kilakila/kilakila_manifest.dart';
import 'package:live_sites/src/platforms/kilakila/kilakila_site.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_failure.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// KilaKila's areas: the two timelines (热门直播 and 萌星推荐), and the rooms
/// under each.
///
/// The platform has no area API: the areas are the catalog's own. Another
/// area id is a caller error, never an empty page.
final class KilakilaAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  KilakilaAreaProvider({required this.site});

  /// The site this capability serves.
  final KilakilaSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async => right(KilakilaRoomParser.areas());

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required LiveArea area,
    LivePageRequest? request,
  }) async {
    request ??= LivePageRequest();
    try {
      final page = await site.timeline(request.page, request.pageSize, areaId: area.areaId);
      return right(LivePage.of(items: page.rooms, hasMore: page.hasMore));
    } on KilakilaFailure catch (failure) {
      return left(failure.toLiveSiteError(kilakilaSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: kilakilaSiteId, message: '$error', cause: error));
    }
  }
}
