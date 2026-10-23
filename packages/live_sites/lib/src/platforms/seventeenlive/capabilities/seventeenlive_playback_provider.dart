import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_failure.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_play_parser.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_room_parser.dart';
import 'package:live_sites/src/platforms/seventeenlive/seventeenlive_manifest.dart';
import 'package:live_sites/src/platforms/seventeenlive/seventeenlive_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// 17LIVE's playback: the qualities of a live and the lines behind one of them,
/// both read from one `lives/<id>` answer.
///
/// The pull URLs are unsigned and do not expire, so the room is entered once and
/// its answer serves both requests: [getQualities] hands out what the held answer
/// offers, in the order the "优先 H.264" setting asks for, and [getLines] answers
/// from the same answer's lines. A quality the held answer does not offer is the
/// recovery the reference made a method of: the answer names the CDN that serves
/// now (REG-17LIVE-002), so the room is entered again and resolved there — which
/// is also why a line carries no lease and no single-use mark.
///
/// A room with nothing to play is never an empty list: offline, a state the
/// platform did not name, a live locked for this viewer (premium, army-only) and
/// a live with no readable pull URL each report their own reason.
final class SeventeenLivePlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  SeventeenLivePlaybackProvider({required this.site});

  /// The site this capability serves.
  final SeventeenLiveSite site;

  /// The last room entered and its playback, which the lines of its qualities
  /// are read from while the room asked for does not change.
  ({String roomId, SeventeenLiveRoomData data})? _snapshot;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required LiveRoom room}) async {
    try {
      return right(SeventeenLivePlayParser.playQualities(await _enter(room.roomId), preferH264: site.preferH264()));
    } on SeventeenLiveFailure catch (failure) {
      return left(failure.toLiveSiteError(seventeenliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: seventeenliveSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required LiveRoom room, LivePlayQuality? quality}) async {
    try {
      final prefer = site.preferH264();
      final wanted = quality?.qualityId?.trim();
      var data = await _held(room.roomId);
      // A held answer that plays but does not know this quality is stale, not
      // refusing: read the room again, as the reference's recovery did. One that
      // has nothing to play at all is reported without a second request.
      if (data.qualities.isNotEmpty &&
          wanted != null &&
          wanted.isNotEmpty &&
          !data.lines.containsKey(SeventeenLivePlayParser.qualityIdFromLegacy(wanted))) {
        data = await _enter(room.roomId);
      }
      return right(SeventeenLivePlayParser.lines(data, quality: wanted, preferH264: prefer));
    } on SeventeenLiveFailure catch (failure) {
      return left(failure.toLiveSiteError(seventeenliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: seventeenliveSiteId, message: '$error', cause: error));
    }
  }

  /// The held playback of [roomId], or the room entered again when another room
  /// was entered last (one answer at a time, as a player watches one stream).
  Future<SeventeenLiveRoomData> _held(String roomId) async {
    final id = roomId.trim();
    if (_snapshot case final held? when held.roomId == id) return held.data;
    return await _enter(id);
  }

  /// The room entered and its playback kept.
  Future<SeventeenLiveRoomData> _enter(String roomId) async {
    final data = await site.playback(roomId);
    _snapshot = (roomId: data.roomId, data: data);
    return data;
  }
}
