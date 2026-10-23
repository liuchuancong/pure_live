import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/chzzk/chzzk_manifest.dart';
import 'package:live_sites/src/platforms/chzzk/chzzk_site.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_failure.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_play_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Chzzk's playback: the qualities of a live and the lines behind one of them.
///
/// Both come from the live's two HLS masters, which the adapter keeps per
/// channel and re-reads by the rule the reference found: lines while no token
/// is due, masters while their tokens hold, and the room itself again once they
/// do not — so a player that follows each line's [LivePlayLine.lease] never
/// replays an exhausted address. Every quality is served by both masters, which
/// is where the platform's normal-latency and low-latency variants differ.
///
/// An offline room, a live this viewer may not watch (region-locked, adult,
/// paid) and a live whose playback data cannot be read are errors that name the
/// reason, never an empty list.
final class ChzzkPlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  ChzzkPlaybackProvider({required this.site});

  /// The site this capability serves.
  final ChzzkSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required LiveRoom room}) async {
    try {
      return right(ChzzkPlayParser.qualities(await site.variantsOf(room.roomId)));
    } on ChzzkFailure catch (failure) {
      return left(failure.toLiveSiteError(chzzkSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: chzzkSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required LiveRoom room, LivePlayQuality? quality}) async {
    try {
      final variants = await site.variantsOf(room.roomId);
      final lines = ChzzkPlayParser.lines(variants, quality: quality?.qualityId);
      if (lines.isEmpty) {
        throw ChzzkFailure(
          ChzzkFailureKind.streamUnavailable,
          'quality ${quality?.qualityId ?? '-'} is not offered right now',
        );
      }
      return right(lines);
    } on ChzzkFailure catch (failure) {
      return left(failure.toLiveSiteError(chzzkSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: chzzkSiteId, message: '$error', cause: error));
    }
  }
}
