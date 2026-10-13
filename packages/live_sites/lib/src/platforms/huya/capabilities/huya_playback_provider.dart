import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/huya/huya_site.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_failure.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_play_parser.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Huya's playback on the web path: qualities and pre-signing lines come from
/// one `profileRoom` answer's embedded `stream`; every line is signed with its
/// own `AntiCode` as the anonymous viewer.
///
/// DEFERRED (documented follow-up, not faked): the native `getCdnTokenInfoEx`
/// WUP play-token refresh (4-byte length-prefixed TUP3 packets over
/// `wup.huya.com`), the headline message board and replay recordings. A
/// restricted room is not opened; a room with no web line is content-unavailable.
final class HuyaPlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  HuyaPlaybackProvider({required this.site});

  /// The site this capability serves.
  final HuyaSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required String roomId}) async {
    try {
      final profile = await _playable(roomId);
      return right(profile.qualities);
    } on HuyaFailure catch (failure) {
      return left(failure.toLiveSiteError('huya'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'huya', message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required String roomId, LivePlayQuality? quality}) async {
    try {
      final profile = await _playable(roomId);
      if (profile.lines.isEmpty) {
        throw const HuyaFailure(HuyaFailureKind.streamUnavailable, 'profileRoom: no multiLine entry with a stream');
      }
      final bitRate = int.tryParse(quality?.qualityId ?? '') ?? 0;
      final rid = profile.room.roomId;
      final viewerUid = await site.viewerUid();
      final cookie = site.cookie();
      final issuedAt = DateTime.now().toUtc();
      final seen = <String>{};
      final lines = <LivePlayLine>[];
      HuyaFailure? last;
      for (final line in profile.lines) {
        try {
          if (line.antiCode.trim().isEmpty) throw HuyaFailure(HuyaFailureKind.streamUnavailable, '$line: no token');
          final signed = HuyaPlayParser.signAntiCode(
            line.antiCode,
            streamName: line.streamName,
            uid: viewerUid,
            clock: site.clock,
            now: site.now(),
          );
          final answer = HuyaPlayParser.answer(
            line,
            antiCode: signed,
            bitRate: bitRate,
            roomId: rid,
            cookie: cookie,
            issuedAt: issuedAt,
          );
          if (seen.add(answer.url)) lines.add(answer);
        } on HuyaFailure catch (failure) {
          // One line that cannot be signed is dropped alone.
          last = failure;
        }
      }
      if (lines.isEmpty) throw last ?? const HuyaFailure(HuyaFailureKind.streamUnavailable, 'no line could be signed');
      return right(lines);
    } on HuyaFailure catch (failure) {
      return left(failure.toLiveSiteError('huya'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'huya', message: '$error', cause: error));
    }
  }

  /// The room's stream data, once it can be played: a live room with a
  /// stream, unrestricted. A restricted room (paid, password, or an
  /// unplayable replay) and a room that is off air are content-unavailable.
  Future<HuyaProfile> _playable(String roomId) async {
    final profile = await site.detailRoom(roomId);
    final restriction = profile.room.broadcast.effectiveRestriction;
    if (restriction != LiveRestriction.none) {
      throw HuyaFailure(HuyaFailureKind.streamUnavailable, 'restricted room (${restriction.name})');
    }
    if (!profile.hasStream) {
      throw HuyaFailure(
        HuyaFailureKind.streamUnavailable,
        'profileRoom: the room is ${profile.room.broadcast.effectiveLiveStatus.name}',
      );
    }
    return profile;
  }
}
