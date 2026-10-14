import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kuaishou/kuaishou_site.dart';
import 'package:live_sites/src/platforms/kuaishou/parsers/kuaishou_failure.dart';
import 'package:live_sites/src/platforms/kuaishou/parsers/kuaishou_play_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Kuaishou's playback: the room page carries the signed `playUrls`, so
/// qualities and lines are read off a fresh detail — there is no play request,
/// no signature to make and no expiry to guess; each line's lease is read from
/// its own URL.
///
/// A room that is off air, or on air with no quality for this client, is
/// content-unavailable rather than an empty list. Media lines carry only the
/// user's cookie (never the anonymous session) and honour "优先 H.264".
final class KuaishouPlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  KuaishouPlaybackProvider({required this.site});

  /// The site this capability serves.
  final KuaishouSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required String roomId}) async {
    try {
      final room = await site.detail(roomId);
      final streams = _streams(room);
      final qualities = KuaishouPlayParser.qualities(streams.playUrls, preferH264: site.preferH264());
      if (qualities.isEmpty) {
        throw const KuaishouFailure(KuaishouFailureKind.streamUnavailable, 'playUrls: no playable representation');
      }
      return right(qualities);
    } on KuaishouFailure catch (failure) {
      return left(failure.toLiveSiteError('kuaishou'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'kuaishou', message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required String roomId, LivePlayQuality? quality}) async {
    try {
      final room = await site.detail(roomId);
      final streams = _streams(room);
      final lines = KuaishouPlayParser.lines(
        streams.playUrls,
        roomId: room.roomId,
        issuedAt: streams.issuedAt,
        qualityId: quality?.qualityId,
        cookie: site.login(),
      );
      if (lines.isEmpty) {
        throw const KuaishouFailure(KuaishouFailureKind.streamUnavailable, 'playUrls: no playable URL');
      }
      return right(lines);
    } on KuaishouFailure catch (failure) {
      return left(failure.toLiveSiteError('kuaishou'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'kuaishou', message: '$error', cause: error));
    }
  }

  /// The `playUrls` a live room's stream handle carries; a room that is not
  /// living, or hands out none, is stream-unavailable.
  ({Object? playUrls, DateTime issuedAt}) _streams(LiveRoom room) {
    final handle = room.runtime.streamHandle;
    if (!room.broadcast.isLiveNow || handle is! KuaishouRoomData || handle.playUrls == null) {
      throw KuaishouFailure(
        KuaishouFailureKind.streamUnavailable,
        'room page: ${room.roomId} has no stream for this client',
      );
    }
    return (playUrls: handle.playUrls, issuedAt: handle.issuedAt);
  }
}
