import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_failure.dart';
import 'package:live_sites/src/platforms/youtube/youtube_manifest.dart';
import 'package:live_sites/src/platforms/youtube/youtube_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Youtube rooms, refreshed: the player and next answers room entry makes.
final class YoutubeRoomRefresh implements LiveRoomRefresh {
  /// Serves [site].
  YoutubeRoomRefresh({required this.site});

  /// The site this capability serves.
  final YoutubeSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRefresh({required String roomId}) async {
    try {
      return right(await site.detail(roomId));
    } on YouTubeFailure catch (failure) {
      return left(failure.toLiveSiteError(youtubeSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: youtubeSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRecording({required String roomId}) =>
      getRoomForRefresh(roomId: roomId);
}
