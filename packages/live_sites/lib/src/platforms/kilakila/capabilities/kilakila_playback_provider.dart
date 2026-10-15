import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/kilakila/kilakila_site.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// KilaKila's playback: the one quality 原画 with its FLV and HLS lines,
/// from the stream data of the anchor's room entry (or a fresh entry when
/// none is kept).
///
/// The pull URLs are signed and expire, so each line carries the lease of
/// its `auth_key`; an expired HLS playlist ends playback, an established FLV
/// connection keeps flowing, and the lease says so. An anchor without a
/// broadcast, one that is over, a paid one and one without a pull URL are
/// errors that name the reason, never an empty list.
final class KilakilaPlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  KilakilaPlaybackProvider({required this.site});

  /// The site this capability serves.
  final KilakilaSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required String roomId}) async {
    try {
      return right(await site.qualitiesOf(roomId));
    } on KilakilaFailure catch (failure) {
      return left(failure.toLiveSiteError('kilakila'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'kilakila', message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required String roomId, LivePlayQuality? quality}) async {
    try {
      return right(await site.linesOf(roomId, quality: quality));
    } on KilakilaFailure catch (failure) {
      return left(failure.toLiveSiteError('kilakila'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'kilakila', message: '$error', cause: error));
    }
  }
}
