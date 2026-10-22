import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/liveme/liveme_manifest.dart';
import 'package:live_sites/src/platforms/liveme/liveme_site.dart';
import 'package:live_sites/src/platforms/liveme/parsers/liveme_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// LiveMe's playback: the qualities 原画 and 流畅 with their FLV and HLS
/// lines, from the stream data of the room's entry (or a fresh broadcast
/// lookup when none is kept).
///
/// The media URLs carry a fixed `wsABStime` that the site does not enforce
/// for the broadcast's length, so a line has no lease. An anchor that is not
/// broadcasting, a broadcast that is over, a private or paid one (naming it)
/// and one without media are errors that name the reason, never an empty
/// list.
final class LivemePlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  LivemePlaybackProvider({required this.site});

  /// The site this capability serves.
  final LivemeSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required String roomId}) async {
    try {
      return right(await site.qualitiesOf(roomId));
    } on LivemeFailure catch (failure) {
      return left(failure.toLiveSiteError(livemeSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: livemeSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required String roomId, LivePlayQuality? quality}) async {
    try {
      return right(await site.linesOf(roomId, quality: quality));
    } on LivemeFailure catch (failure) {
      return left(failure.toLiveSiteError(livemeSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: livemeSiteId, message: '$error', cause: error));
    }
  }
}
