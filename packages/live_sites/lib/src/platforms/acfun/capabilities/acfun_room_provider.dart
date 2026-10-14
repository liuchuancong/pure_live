import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/acfun/acfun_site.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// AcFun's rooms: the author's `live/info` (plus `startPlay` when it says
/// live) for detail, the site-wide directory as the default listing.
///
/// The room's identity is the author id, which is also what the stream handle
/// and the danmaku arguments are keyed by.
final class AcfunRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  AcfunRoomProvider({required this.site});

  /// The site this capability serves.
  final AcfunSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await site.detail(roomId));
    } on AcfunFailure catch (failure) {
      return left(failure.toLiveSiteError('acfun'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'acfun', message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      final page = await site.listing(page: request.page, pageSize: request.pageSize);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore, nextCursor: page.nextCursor));
    } on AcfunFailure catch (failure) {
      return left(failure.toLiveSiteError('acfun'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'acfun', message: '$error', cause: error));
    }
  }
}
