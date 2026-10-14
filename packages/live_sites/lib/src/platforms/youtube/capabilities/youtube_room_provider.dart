import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_failure.dart';
import 'package:live_sites/src/platforms/youtube/youtube_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// YouTube's rooms: the `player` + `next` pair for detail, the Live hub as the
/// default directory.
///
/// The room's identity is the broadcaster's channel id; this broadcast's
/// `videoId`, its streaming handles and the live-chat continuation ride in the
/// room's runtime handles for playback and the comment feed.
final class YoutubeRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  YoutubeRoomProvider({required this.site});

  /// The site this capability serves.
  final YoutubeSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await site.detail(roomId));
    } on YouTubeFailure catch (failure) {
      return left(failure.toLiveSiteError('youtube'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'youtube', message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      if (request.page > 1) return right(const LivePage(items: [], hasMore: false));
      final hub = await site.hub();
      return right(LivePage(items: hub.rooms, hasMore: false));
    } on YouTubeFailure catch (failure) {
      return left(failure.toLiveSiteError('youtube'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'youtube', message: '$error', cause: error));
    }
  }
}
