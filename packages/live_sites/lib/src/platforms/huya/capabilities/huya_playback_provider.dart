import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/huya/huya_manifest.dart';
import 'package:live_sites/src/platforms/huya/huya_site.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_failure.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_play_parser.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Huya's playback: qualities and lines come from one `profileRoom` answer's
/// embedded `stream`. An FLV line is signed with a WUP play token — the native
/// `getCdnTokenInfoEx` credential first (the pc_exe identity), falling back to a
/// web token, then to the room's own AntiCode template; an HLS line (and a room
/// template with no `fm`) is signed on the web path. A fetched token's window
/// bounds the line's lease. A restricted room is not opened; a room with no
/// line is content-unavailable.
final class HuyaPlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  HuyaPlaybackProvider({required this.site});

  /// The site this capability serves.
  final HuyaSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required LiveRoom room}) async {
    try {
      final profile = await _playable(room.roomId);
      // A replay offers every definition of its recording (getMomentContent),
      // falling back to the one quality profileRoom named.
      final videoId = profile.replay?.videoId;
      if (videoId != null) {
        final definitions = await site.replayQualities(videoId);
        return right(definitions.isEmpty ? profile.qualities : definitions);
      }
      return right(profile.qualities);
    } on HuyaFailure catch (failure) {
      return left(failure.toLiveSiteError(huyaSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: huyaSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required LiveRoom room, LivePlayQuality? quality}) async {
    try {
      final profile = await _playable(room.roomId);
      final rid = profile.room.roomId;
      final cookie = site.cookie();
      // A replay plays its recording: an unsigned VOD playlist that does not
      // expire (no lease, no signature). The chosen definition's playlist is
      // the quality's id; without one, the recording profileRoom named.
      if (profile.replay case final replay?) {
        final requested = quality?.qualityId ?? '';
        final url = HuyaPlayParser.replayUrl(requested) ?? replay.url;
        return right([
          LivePlayLine.of(
            url: url,
            format: LiveStreamFormat.hls,
            formatSource: LivePlayFormatSource.declared,
            headers: HuyaPlayParser.mediaHeaders(rid, cookie: cookie),
            codec: LiveStreamCodec.avc,
          ),
        ]);
      }
      if (profile.lines.isEmpty) {
        throw const HuyaFailure(HuyaFailureKind.streamUnavailable, 'profileRoom: no multiLine entry with a stream');
      }
      final bitRate = int.tryParse(quality?.qualityId ?? '') ?? 0;
      final viewerUid = await site.viewerUid();
      final issuedAt = DateTime.now().toUtc();
      final seen = <String>{};
      final lines = <LivePlayLine>[];
      HuyaFailure? last;
      for (final line in profile.lines) {
        try {
          final signed = await _sign(line, viewerUid);
          final answer = HuyaPlayParser.answer(
            line,
            antiCode: signed.antiCode,
            bitRate: bitRate,
            roomId: rid,
            cookie: cookie,
            issuedAt: issuedAt,
            token: signed.window,
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
      return left(failure.toLiveSiteError(huyaSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: huyaSiteId, message: '$error', cause: error));
    }
  }

  /// The anti-code a [line] is signed with and the token window that bounds it:
  ///
  /// 1. FLV asks the native WUP token and signs with it; when that fails, the
  ///    room template is signed as the viewer; when that fails too, a web WUP
  ///    token is fetched for this viewer and line;
  /// 2. a room token with no `fm` is a legacy static token used as is; a
  ///    template is signed as the viewer;
  /// 3. HLS uses only its own AntiCode, signed as the viewer — the web path
  ///    never uses the native identity.
  Future<({String antiCode, HuyaTokenWindow? window})> _sign(HuyaLine line, int viewerUid) async {
    final room = line.antiCode.trim();
    var antiCode = room;
    HuyaTokenWindow? window;
    var signed = false;
    if (line.format == LiveStreamFormat.flv) {
      try {
        final token = await site.nativeToken(line.streamName);
        final native = HuyaPlayParser.tokenWindow(
          token.token,
          expireTime: token.expireTime,
          receivedAt: token.receivedAt,
        );
        if (!site.now().toUtc().isBefore(native.invalidAt)) {
          throw const HuyaFailure(
            HuyaFailureKind.streamUnavailable,
            'getCdnTokenInfoEx: the native token arrived expired',
          );
        }
        antiCode = _signWith(token.token, line, line.presenterUid > 0 ? line.presenterUid : viewerUid);
        window = native;
        signed = true;
      } on HuyaFailure {
        // The native token path failed; fall back to the room template.
      }
      if (!signed && HuyaPlayParser.hasTemplate(room)) {
        HuyaFailure? signFailure;
        try {
          antiCode = _signWith(room, line, viewerUid);
          signed = true;
        } on HuyaFailure catch (failure) {
          signFailure = failure;
        }
        if (!signed) {
          try {
            final token = await site.webToken(flvUrl: line.base, streamName: line.streamName, uid: viewerUid);
            window = HuyaPlayParser.tokenWindow(
              token.token,
              expireTime: token.expireTime,
              receivedAt: token.receivedAt,
            );
            antiCode = token.token;
          } on HuyaFailure {
            // The line fails with the root cause: the template signing error.
            throw signFailure!;
          }
        }
      }
    }
    if (antiCode.isEmpty) throw HuyaFailure(HuyaFailureKind.streamUnavailable, '${line.cdnType}: no token');
    if (!signed && HuyaPlayParser.hasTemplate(antiCode)) antiCode = _signWith(antiCode, line, viewerUid);
    return (antiCode: antiCode, window: window);
  }

  String _signWith(String antiCode, HuyaLine line, int uid) => HuyaPlayParser.signAntiCode(
    antiCode,
    streamName: line.streamName,
    uid: uid > 0 ? uid : site.fallbackUid,
    clock: site.clock,
    now: site.now(),
  );

  /// The room's stream data, once it can be played: a live room with a
  /// stream, or a replay with a recording, unrestricted. A restricted room
  /// (paid, password, or a replay with no recording) and a room that is off
  /// air are content-unavailable.
  Future<HuyaProfile> _playable(String roomId) async {
    final profile = await site.detailRoom(roomId);
    final restriction = profile.room.broadcast.effectiveRestriction;
    if (restriction != LiveRestriction.none) {
      throw HuyaFailure(HuyaFailureKind.streamUnavailable, 'restricted room (${restriction.name})');
    }
    if (!profile.hasStream && profile.replay == null) {
      throw HuyaFailure(
        HuyaFailureKind.streamUnavailable,
        'profileRoom: the room is ${profile.room.broadcast.effectiveLiveStatus.name}',
      );
    }
    return profile;
  }
}
