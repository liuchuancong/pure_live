import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/missevan/missevan_manifest.dart';
import 'package:live_sites/src/platforms/missevan/missevan_site.dart';
import 'package:live_sites/src/platforms/missevan/parsers/missevan_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Missevan's playback: the one quality 原画 with its FLV and HLS lines, from
/// the room entry the entry brought (or a fresh entry when none is kept).
///
/// The pull URLs are signed and expire, so each line carries the lease of its
/// `expires`; an expired HLS playlist ends playback, an established FLV
/// connection keeps flowing, and the lease says so. A room that is not live,
/// or live without a pull URL, is an error that names the reason, never an
/// empty list.
final class MissevanPlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  MissevanPlaybackProvider({required this.site});

  /// The site this capability serves.
  final MissevanSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required String roomId}) async {
    try {
      return right(await site.qualitiesOf(roomId));
    } on MissevanFailure catch (failure) {
      return left(failure.toLiveSiteError(missevanSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: missevanSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required String roomId, LivePlayQuality? quality}) async {
    try {
      return right(await site.linesOf(roomId, quality: quality));
    } on MissevanFailure catch (failure) {
      return left(failure.toLiveSiteError(missevanSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: missevanSiteId, message: '$error', cause: error));
    }
  }
}
