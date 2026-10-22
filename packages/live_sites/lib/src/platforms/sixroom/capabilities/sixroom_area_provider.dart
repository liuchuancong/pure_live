import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_failure.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_room_parser.dart';
import 'package:live_sites/src/platforms/sixroom/sixroom_manifest.dart';
import 'package:live_sites/src/platforms/sixroom/sixroom_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Six Rooms' areas: the six fixed ones (全部, 歌区, 舞区, 脱口秀, 星颜, 派对),
/// and the rooms under each.
///
/// 全部 is the platform's homepage (every live room), 歌区, 舞区, 脱口秀 and
/// 派对 the app's mobile lists, 星颜 the web's subarea list. Another area id
/// is a caller error, never an empty page.
final class SixroomAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  SixroomAreaProvider({required this.site});

  /// The site this capability serves.
  final SixroomSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async => right(SixroomRoomParser.areas());

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required String areaId,
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final page = await site.directoryPage(request.page, request.pageSize, areaId: areaId);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on SixroomFailure catch (failure) {
      return left(failure.toLiveSiteError(sixroomSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: sixroomSiteId, message: '$error', cause: error));
    }
  }
}
