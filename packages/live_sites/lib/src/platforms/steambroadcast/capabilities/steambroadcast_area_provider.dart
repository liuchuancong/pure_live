import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_failure.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_room_parser.dart';
import 'package:live_sites/src/platforms/steambroadcast/steambroadcast_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Steam Broadcast's areas: the one area of the trending broadcasts, and its
/// pages of rooms.
///
/// The platform has no area API: the area is the catalog's own. Another area
/// id is a caller error, never an empty page.
final class SteambroadcastAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  SteambroadcastAreaProvider({required this.site});

  /// The site this capability serves.
  final SteambroadcastSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async => right(SteambroadcastRoomParser.areas());

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required LiveArea area,
    LivePageRequest? request,
  }) async {
    request ??= LivePageRequest();
    try {
      final page = await site.areaRooms(area.areaId, request.page);
      return right(LivePage.of(items: page.rooms, hasMore: page.hasMore));
    } on SteambroadcastFailure catch (failure) {
      return left(failure.toLiveSiteError(siteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: siteId, message: '$error', cause: error));
    }
  }
}
