import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/inke/inke_manifest.dart';
import 'package:live_sites/src/platforms/inke/inke_site.dart';
import 'package:live_sites/src/platforms/inke/parsers/inke_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Inke's areas: the website's top list and its channels, and the rooms
/// under each.
///
/// The catalog comes from `Live_channel_pc`; its areas carry the one
/// category 映客 as their parent. Another area id is a caller error, never
/// an empty page, and a listed channel the showcase does not hold is
/// not-found.
final class InkeAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  InkeAreaProvider({required this.site});

  /// The site this capability serves.
  final InkeSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async {
    try {
      return right(await site.areas());
    } on InkeFailure catch (failure) {
      return left(failure.toLiveSiteError(inkeSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: inkeSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required String areaId,
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final page = await site.areaRooms(areaId, page: request.page);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on InkeFailure catch (failure) {
      return left(failure.toLiveSiteError(inkeSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: inkeSiteId, message: '$error', cause: error));
    }
  }
}
