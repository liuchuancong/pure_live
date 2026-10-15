import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/kugoulive/kugoulive_site.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Kugou Live's playback: the qualities of the stream answer (one per
/// protocol, bitrate tier, codec and layout) and the lines behind each.
///
/// The lines carry the media headers and the lease of their `txTime`; the
/// qualities list H.264 first while "优先 H.264" is on, so the default is
/// never HEVC. A room that is offline, asks for a login or answers no
/// stream says why, never an empty list.
final class KugoulivePlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  KugoulivePlaybackProvider({required this.site});

  /// The site this capability serves.
  final KugouliveSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required String roomId}) =>
      _run(() => site.qualitiesOf(roomId));

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required String roomId, LivePlayQuality? quality}) =>
      _run(() => site.linesOf(roomId, quality: quality));

  Future<Either<LiveSiteError, T>> _run<T>(Future<T> Function() work) async {
    try {
      return right(await work());
    } on KugouliveFailure catch (failure) {
      return left(failure.toLiveSiteError('kugoulive'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'kugoulive', message: '$error', cause: error));
    }
  }
}
