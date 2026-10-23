import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/douyin/douyin_manifest.dart';
import 'package:live_sites/src/platforms/douyin/douyin_site.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_failure.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_play_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Douyin's playback: the web room answer carries the URLs, so qualities and
/// lines are read off `room.stream_url` of a fresh detail — there is no play
/// request and nothing to sign for the stream itself.
///
/// A room that is off air, or on air without a video for this client (audio
/// only, or no stream at all), is content-unavailable rather than an empty
/// list; each line's lease says when the detail must be fetched again.
final class DouyinPlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  DouyinPlaybackProvider({required this.site});

  /// The site this capability serves.
  final DouyinSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required LiveRoom room}) async {
    try {
      final fetched = await _streamed(room.roomId);
      return right(DouyinPlayParser.qualities(fetched.room.streamUrl));
    } on DouyinFailure catch (failure) {
      return left(failure.toLiveSiteError(douyinSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: douyinSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required LiveRoom room, LivePlayQuality? quality}) async {
    try {
      final fetched = await _streamed(room.roomId);
      final lines = DouyinPlayParser.lines(
        fetched.room.streamUrl,
        webRid: fetched.room.room.roomId,
        issuedAt: fetched.issuedAt,
        qualityId: quality?.qualityId,
        cookie: fetched.cookie,
      );
      if (lines.isEmpty) {
        throw const DouyinFailure(DouyinFailureKind.streamUnavailable, 'stream_url: no playable URL');
      }
      return right(lines);
    } on DouyinFailure catch (failure) {
      return left(failure.toLiveSiteError(douyinSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: douyinSiteId, message: '$error', cause: error));
    }
  }

  /// A detail whose room actually offers a stream: live, unrestricted, and
  /// with at least one video quality in `stream_url`.
  Future<DouyinFetched> _streamed(String roomId) async {
    final fetched = await site.fetch(roomId);
    final room = fetched.room;
    final broadcast = room.room.broadcast;
    if (broadcast.effectiveRestriction != LiveRestriction.none) {
      throw DouyinFailure(
        DouyinFailureKind.streamUnavailable,
        'room ${room.room.roomId} is restricted (${broadcast.effectiveRestriction.name})',
      );
    }
    if (!broadcast.isLiveNow || DouyinPlayParser.qualities(room.streamUrl).isEmpty) {
      throw DouyinFailure(
        DouyinFailureKind.streamUnavailable,
        'room ${room.room.roomId}: no video stream (${broadcast.effectiveLiveStatus.name})',
      );
    }
    return fetched;
  }
}
