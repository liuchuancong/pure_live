import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/inke/inke_site.dart';
import 'package:live_sites/src/platforms/inke/parsers/inke_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Inke's playback: the H.264 FLV quality every live broadcast plays, and
/// the original HEVC one when the app gave its Zego line — from the stream
/// data of the room's entry (or a fresh entry when none is kept).
///
/// The pull URLs are signed and expire, so each line carries the lease of
/// its `wsABStime`; the CDN checks it when a connection opens, so an
/// established FLV connection keeps flowing past the renewal time. A room
/// the platform calls offline, an anchor the app says is not live, and a
/// broadcast whose pull URL no showcase holds are errors that name the
/// reason, never an empty list.
final class InkePlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  InkePlaybackProvider({required this.site});

  /// The site this capability serves.
  final InkeSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required String roomId}) async {
    try {
      return right(await site.qualitiesOf(roomId));
    } on InkeFailure catch (failure) {
      return left(failure.toLiveSiteError('inke'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'inke', message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required String roomId, LivePlayQuality? quality}) async {
    try {
      return right(await site.linesOf(roomId, quality: quality));
    } on InkeFailure catch (failure) {
      return left(failure.toLiveSiteError('inke'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'inke', message: '$error', cause: error));
    }
  }
}
