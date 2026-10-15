import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/twitcasting/parsers/twitcasting_failure.dart';
import 'package:live_sites/src/platforms/twitcasting/twitcasting_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// TwitCasting's playback: the HLS tiers of the broadcast the room entry
/// brought (or a fresh `streamserver.php` answer when none is kept), best
/// first.
///
/// The tier playlist carries no signature or expiry, so its line has no
/// lease. A channel that is not broadcasting, and one whose broadcast is
/// password-protected, are errors that name the reason, never an empty list.
final class TwitcastingPlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  TwitcastingPlaybackProvider({required this.site});

  /// The site this capability serves.
  final TwitcastingSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required String roomId}) async {
    try {
      return right(await site.qualitiesOf(roomId));
    } on TwitcastingFailure catch (failure) {
      return left(failure.toLiveSiteError('twitcasting'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'twitcasting', message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required String roomId, LivePlayQuality? quality}) async {
    try {
      return right(await site.linesOf(roomId, quality: quality));
    } on TwitcastingFailure catch (failure) {
      return left(failure.toLiveSiteError('twitcasting'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'twitcasting', message: '$error', cause: error));
    }
  }
}
