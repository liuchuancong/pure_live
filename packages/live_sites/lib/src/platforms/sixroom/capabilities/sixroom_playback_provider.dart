import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_failure.dart';
import 'package:live_sites/src/platforms/sixroom/sixroom_manifest.dart';
import 'package:live_sites/src/platforms/sixroom/sixroom_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Six Rooms' playback: the one quality `FLV 原始线路` with its unsigned FLV
/// line, from the stream data of the room's entry (or a fresh entry when
/// none is kept).
///
/// The stream address is not signed and has no expiry, so the line carries
/// no lease. An offline or unknown room, a private or black-screen one, one
/// whose stream name is unusable and a quality other than the platform's say
/// why nothing plays, never an empty list.
final class SixroomPlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  SixroomPlaybackProvider({required this.site});

  /// The site this capability serves.
  final SixroomSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required LiveRoom room}) async {
    try {
      return right(await site.qualitiesOf(room.roomId));
    } on SixroomFailure catch (failure) {
      return left(failure.toLiveSiteError(sixroomSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: sixroomSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required LiveRoom room, LivePlayQuality? quality}) async {
    try {
      return right(await site.linesOf(room.roomId, quality: quality));
    } on SixroomFailure catch (failure) {
      return left(failure.toLiveSiteError(sixroomSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: sixroomSiteId, message: '$error', cause: error));
    }
  }
}
