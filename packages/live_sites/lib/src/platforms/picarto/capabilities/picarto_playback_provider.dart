import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/picarto/parsers/picarto_failure.dart';
import 'package:live_sites/src/platforms/picarto/picarto_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Picarto's playback: the qualities of the master playlist room entry read,
/// and their variant lines.
///
/// The lines carry the platform's headers and their edge host as the label;
/// the URLs are unsigned, so there is no lease — the load balancer can move
/// the stream to another edge, which the next room entry asks again. A
/// channel that is off the air or private says why it has no stream, never
/// an empty list.
final class PicartoPlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  PicartoPlaybackProvider({required this.site});

  /// The site this capability serves.
  final PicartoSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required String roomId}) async {
    try {
      return right(await site.qualitiesOf(roomId));
    } on PicartoFailure catch (failure) {
      return left(failure.toLiveSiteError('picarto'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'picarto', message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required String roomId, LivePlayQuality? quality}) async {
    try {
      return right(await site.linesOf(roomId, quality: quality));
    } on PicartoFailure catch (failure) {
      return left(failure.toLiveSiteError('picarto'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'picarto', message: '$error', cause: error));
    }
  }
}
