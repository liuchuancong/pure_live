import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_failure.dart';
import 'package:live_sites/src/platforms/tiktok/tiktok_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// TikTok's rooms: the entry of one user's LIVE (one request, with the
/// streams in the runtime handle), and the directory — always an empty last
/// page, since no public directory is reachable anonymously.
///
/// A room id is the lower-case username; anything else is not-found, without
/// a request.
final class TiktokRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  TiktokRoomProvider({required this.site});

  /// The site this capability serves.
  final TiktokSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await site.detail(roomId));
    } on TiktokFailure catch (failure) {
      return left(failure.toLiveSiteError('tiktok'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'tiktok', message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      final page = await site.directory(request.page);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on TiktokFailure catch (failure) {
      return left(failure.toLiveSiteError('tiktok'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'tiktok', message: '$error', cause: error));
    }
  }
}
