import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_failure.dart';
import 'package:live_sites/src/platforms/twitch/twitch_manifest.dart';
import 'package:live_sites/src/platforms/twitch/twitch_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Twitch's rooms: the channel's `user` query for detail, the site's busiest
/// streams as the default directory.
///
/// The room id is the channel login, kept as the user asked for it.
final class TwitchRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  TwitchRoomProvider({required this.site});

  /// The site this capability serves.
  final TwitchSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await site.detail(roomId));
    } on TwitchFailure catch (failure) {
      return left(failure.toLiveSiteError(twitchSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: twitchSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      final result = await site.recommend(request.page, request.pageSize);
      return right(LivePage(items: result.rooms, hasMore: result.hasMore));
    } on TwitchFailure catch (failure) {
      return left(failure.toLiveSiteError(twitchSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: twitchSiteId, message: '$error', cause: error));
    }
  }
}
