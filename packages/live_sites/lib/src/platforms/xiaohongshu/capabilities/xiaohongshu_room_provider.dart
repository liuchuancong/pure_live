import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_failure.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_manifest.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Xiaohongshu's rooms: the entry of one share page (the card, the state
/// and the pull addresses), and the directory — empty without a visitor
/// bootstrap, the guest feed's pages once one is injected (the site's
/// [XiaohongshuSite.directory] decides).
///
/// A room id is a broadcast room: 1–20 digits without a leading zero;
/// anything else is not-found, without a request. An ended room is offline,
/// never unknown.
final class XiaohongshuRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  XiaohongshuRoomProvider({required this.site});

  /// The site this capability serves.
  final XiaohongshuSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await site.detail(roomId));
    } on XiaohongshuFailure catch (failure) {
      return left(failure.toLiveSiteError(xiaohongshuSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: xiaohongshuSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      final page = await site.directory(request.page, cursor: request.cursor);
      return right(LivePage.of(items: page.rooms, hasMore: page.hasMore, nextCursor: page.nextCursor));
    } on XiaohongshuFailure catch (failure) {
      return left(failure.toLiveSiteError(xiaohongshuSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: xiaohongshuSiteId, message: '$error', cause: error));
    }
  }
}
