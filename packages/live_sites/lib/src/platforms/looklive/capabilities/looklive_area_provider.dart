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

/// LOOK Live's areas: the one category LOOK 直播 with its video and voice
/// areas, and the rooms under each.
///
/// The areas are the catalog's own (the interface's two fixed timelines);
/// another area is a caller error, never an empty page.
final class LookliveAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  LookliveAreaProvider({required this.site});

  /// The site this capability serves.
  final LookliveSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async => right(LookliveRoomParser.areas());

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required LiveArea area,
    LivePageRequest? request,
  }) async {
    request ??= LivePageRequest();
    try {
      final kind = LookliveRoomParser.kindOf(area);
      final page = await site.listing(request.page, kind: kind, pageSize: request.pageSize);
      return right(LivePage.of(items: page.rooms, hasMore: page.hasMore));
    } on LookliveFailure catch (failure) {
      return left(failure.toLiveSiteError(lookliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: lookliveSiteId, message: '$error', cause: error));
    }
  }
}
