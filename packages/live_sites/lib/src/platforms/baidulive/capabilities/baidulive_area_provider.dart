import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/baidulive/baidulive_manifest.dart';
import 'package:live_sites/src/platforms/baidulive/baidulive_site.dart';
import 'package:live_sites/src/platforms/baidulive/parsers/baidulive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Baidu Live's areas: the PC feed's channels (推荐, 购物, 财经…), and the rooms
/// of each channel's feed.
///
/// The areas need no request: they are the channels the last first feed page
/// brought, or 3.x's fixed list until one did. Another area id is a caller
/// error, refused without a request, never an empty page; so is a page past
/// the last one the directory ever serves.
final class BaiduliveAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  BaiduliveAreaProvider({required this.site});

  /// The site this capability serves.
  final BaiduliveSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async => right(site.areas());

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required String areaId,
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final page = await site.areaRooms(areaId, page: request.page, pageSize: request.pageSize);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on BaiduliveFailure catch (failure) {
      return left(failure.toLiveSiteError(baiduliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: baiduliveSiteId, message: '$error', cause: error));
    }
  }
}
