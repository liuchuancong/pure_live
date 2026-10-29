import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_plan_resolver.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/play/live_playback_plan/live_playback_plan.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/douyin/douyin_manifest.dart';
import 'package:live_sites/src/platforms/douyin/douyin_site.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_failure.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_play_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Douyin's playback: the web room answer carries the URLs, so qualities and
/// lines are read off `room.stream_url` — from the room's own detail while
/// that answer still stands, from a fresh one after it. There is no play
/// request and nothing to sign for the stream itself.
///
/// A room that is off air, or on air without a video for this client (audio
/// only, or no stream at all), is content-unavailable rather than an empty
/// list; each line's lease says when the detail must be fetched again.
final class DouyinPlaybackProvider implements LivePlaybackProvider, LivePlaybackPlanResolver {
  /// Serves [site].
  DouyinPlaybackProvider({required this.site});

  /// The site this capability serves.
  final DouyinSite site;

  /// How long the room's own detail may serve playback (see [_streamed]).
  static const Duration playbackHandleWindow = Duration(seconds: 5);

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required LiveRoom room}) async {
    try {
      final stream = await _streamed(room);
      return right(DouyinPlayParser.qualities(stream.streamUrl));
    } on DouyinFailure catch (failure) {
      return left(failure.toLiveSiteError(douyinSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: douyinSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required LiveRoom room, LivePlayQuality? quality}) async {
    try {
      final stream = await _streamed(room);
      final lines = DouyinPlayParser.lines(
        stream.streamUrl,
        webRid: stream.webRid,
        issuedAt: stream.issuedAt,
        qualityId: quality?.qualityId,
        cookie: stream.cookie,
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

  /// The plan for [room]: its lines plus the quality actually served (a
  /// stale id plays the best variant the room offers).
  @override
  Future<Either<LiveSiteError, LivePlaybackPlan>> resolvePlan({
    required LiveRoom room,
    LivePlayQuality? quality,
  }) async {
    try {
      final stream = await _streamed(room);
      final resolution = DouyinPlayParser.resolvedLines(
        stream.streamUrl,
        webRid: stream.webRid,
        issuedAt: stream.issuedAt,
        qualityId: quality?.qualityId,
        cookie: stream.cookie,
      );
      if (resolution.lines.isEmpty) {
        throw const DouyinFailure(DouyinFailureKind.streamUnavailable, 'stream_url: no playable URL');
      }
      return right(LivePlaybackPlan.of(lines: resolution.lines, appliedQuality: resolution.appliedQuality));
    } on DouyinFailure catch (failure) {
      return left(failure.toLiveSiteError(douyinSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: douyinSiteId, message: '$error', cause: error));
    }
  }

  /// The stream answer playback reads: [room]'s own detail while it is still
  /// the room being played, live, unrestricted, with a video and younger than
  /// [playbackHandleWindow], else a fresh detail.
  ///
  /// The window is the whole of it: one open (detail, chat, qualities, lines)
  /// shares a single signed enter, while a recovery or a lease renewal — which
  /// arrives seconds to minutes after the room opened — always re-reads and so
  /// never plays back the address it is recovering from.
  Future<_DouyinStream> _streamed(LiveRoom room) async {
    final handle = room.runtime.streamHandle;
    if (handle is DouyinRoomData && _stillServes(handle, room)) {
      return (
        streamUrl: handle.streamUrl,
        webRid: handle.webRid,
        issuedAt: handle.issuedAt,
        cookie: site.knownCookie(),
      );
    }
    final fetched = await site.fetch(room.roomId);
    final parse = fetched.room;
    final broadcast = parse.room.broadcast;
    if (broadcast.effectiveRestriction != LiveRestriction.none) {
      throw DouyinFailure(
        DouyinFailureKind.streamUnavailable,
        'room ${parse.room.roomId} is restricted (${broadcast.effectiveRestriction.name})',
      );
    }
    if (!broadcast.isLiveNow || DouyinPlayParser.qualities(parse.streamUrl).isEmpty) {
      throw DouyinFailure(
        DouyinFailureKind.streamUnavailable,
        'room ${parse.room.roomId}: no video stream (${broadcast.effectiveLiveStatus.name})',
      );
    }
    return (
      streamUrl: parse.streamUrl,
      webRid: parse.room.roomId,
      issuedAt: fetched.issuedAt,
      cookie: fetched.cookie,
    );
  }

  /// Whether [handle] is still the answer for [room] (see [_streamed]).
  bool _stillServes(DouyinRoomData handle, LiveRoom room) =>
      handle.streamUrl != null &&
      handle.webRid == room.roomId &&
      room.broadcast.isLiveNow &&
      room.broadcast.effectiveRestriction == LiveRestriction.none &&
      DouyinPlayParser.qualities(handle.streamUrl).isNotEmpty &&
      site.now().difference(handle.issuedAt) <= playbackHandleWindow;
}

/// The four things a stream answer carries: the platform's `stream_url`, the
/// room it was read for, when it arrived and the cookie its media headers
/// carry.
typedef _DouyinStream = ({Map<String, dynamic>? streamUrl, String webRid, DateTime issuedAt, String cookie});
