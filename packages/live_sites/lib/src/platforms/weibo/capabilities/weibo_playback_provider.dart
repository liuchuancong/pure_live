import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/weibo/parsers/weibo_failure.dart';
import 'package:live_sites/src/platforms/weibo/parsers/weibo_room_parser.dart';
import 'package:live_sites/src/platforms/weibo/weibo_manifest.dart';
import 'package:live_sites/src/platforms/weibo/weibo_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Weibo's playback: the broadcast's one quality with the public transcoding
/// profiles a bounded FLV probe confirms (原画, 蓝光, 超清, 高清), and the lines
/// behind them.
///
/// The media URLs carry no signature and no expiry: the lines need no lease,
/// and are handed out with no headers (the CDN answers the FLV and the replay
/// VOD without any; the player sends its own defaults). A broadcast that
/// ended, was never on, is restricted, or switched off is refused with its
/// reason as a content-unavailable left, never an empty list; a live playback
/// re-reads the detail each call, and a probed profile is rebuilt from the
/// fresh answer's own address, never from a caller-supplied URL. The room's
/// own detail handle answers before the site's kept one.
final class WeiboPlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  WeiboPlaybackProvider({required this.site});

  /// The site this capability serves.
  final WeiboSite site;

  /// The room's own playback handle, when it is this platform's.
  WeiboRoomData? _handle(LiveRoom room) {
    final handle = room.runtime.streamHandle;
    return handle is WeiboRoomData ? handle : null;
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required LiveRoom room}) async {
    try {
      return right(await site.discoveredQualities(room.roomId, data: _handle(room)));
    } on WeiboFailure catch (failure) {
      return left(failure.toLiveSiteError(weiboSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: weiboSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required LiveRoom room, LivePlayQuality? quality}) async {
    try {
      return right(await site.linesOf(room.roomId, quality: quality, data: _handle(room)));
    } on WeiboFailure catch (failure) {
      return left(failure.toLiveSiteError(weiboSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: weiboSiteId, message: '$error', cause: error));
    }
  }
}
