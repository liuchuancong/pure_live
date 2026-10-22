import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/looklive/looklive_manifest.dart';
import 'package:live_sites/src/platforms/looklive/looklive_site.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_failure.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// LOOK Live's areas: the one category's video (视频直播) and voice (语音直播)
/// areas, and the rooms under each.
///
/// The platform has no area API: the areas are the catalog's own. Another
/// area id is a caller error, never an empty page.
final class LookliveAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  LookliveAreaProvider({required this.site});

  /// The site this capability serves.
  final LookliveSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async => right(LookliveRoomParser.areas());

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required String areaId,
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final page = await site.directory(request.page, areaId: areaId);
      // A size below 1 asks for nothing (the merged recommendations do too).
      final rooms = request.pageSize < 1 ? const <LiveRoom>[] : page.rooms.take(request.pageSize).toList();
      return right(LivePage(items: rooms, hasMore: page.hasMore));
    } on LookliveFailure catch (failure) {
      return left(failure.toLiveSiteError(lookliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: lookliveSiteId, message: '$error', cause: error));
    }
  }
}
