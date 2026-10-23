import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/weibo/parsers/weibo_failure.dart';
import 'package:live_sites/src/platforms/weibo/weibo_manifest.dart';
import 'package:live_sites/src/platforms/weibo/weibo_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Weibo's areas: the one static area, 公开推荐 — the recommendation
/// snapshot — and its rooms.
///
/// The catalog costs no request; the snapshot is the one page it is, and a
/// page after the first is empty without another request. Another area id
/// is a caller error, never an empty page.
final class WeiboAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  WeiboAreaProvider({required this.site});

  /// The site this capability serves.
  final WeiboSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async {
    try {
      return right(await site.areas());
    } on WeiboFailure catch (failure) {
      return left(failure.toLiveSiteError(weiboSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: weiboSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required String areaId,
    LivePageRequest? request,
  }) async {
    request ??= LivePageRequest();
    try {
      final page = await site.areaRooms(areaId, page: request.page);
      return right(LivePage.of(items: page.rooms, hasMore: page.hasMore));
    } on WeiboFailure catch (failure) {
      return left(failure.toLiveSiteError(weiboSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: weiboSiteId, message: '$error', cause: error));
    }
  }
}
