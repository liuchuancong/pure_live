import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/twitcasting/parsers/twitcasting_failure.dart';
import 'package:live_sites/src/platforms/twitcasting/twitcasting_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// TwitCasting's rooms: the entry of one channel (channel page plus
/// `streamserver.php`), and pages of the whole site's window.
///
/// A room id is a channel (screen id, lower case, with its optional `c:`,
/// `g:`, `f:` or `ig:` prefix); anything else is not-found, without a
/// request.
final class TwitcastingRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  TwitcastingRoomProvider({required this.site});

  /// The site this capability serves.
  final TwitcastingSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await site.detail(roomId));
    } on TwitcastingFailure catch (failure) {
      return left(failure.toLiveSiteError('twitcasting'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'twitcasting', message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      final page = await site.recommend(request.page, request.pageSize);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on TwitcastingFailure catch (failure) {
      return left(failure.toLiveSiteError('twitcasting'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'twitcasting', message: '$error', cause: error));
    }
  }
}
