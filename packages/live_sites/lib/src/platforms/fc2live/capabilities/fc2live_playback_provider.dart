import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/fc2live/fc2live_manifest.dart';
import 'package:live_sites/src/platforms/fc2live/fc2live_site.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// FC2 Live's playback: the qualities a channel's control offers and the one
/// line of a quality.
///
/// A playlist address is only worth asking for while the control socket that
/// announced it is open, and the platform gives no way to hand that socket to
/// the player — so the adapter holds one control per channel and hands out its
/// playlists until that grant is nearly due (see `Fc2LiveSite.heldOf`). Each
/// line is leased for the rest of its grant and its
/// [LivePlayLine.lease] requires a reconnect, which is the closest the contract
/// comes to the reference's rule that whoever plays a channel keeps its control
/// open.
///
/// A channel that is not on air, one the platform keeps from anonymous viewers,
/// and one whose grant or answer cannot be read are errors that name the reason,
/// never an empty list.
final class Fc2LivePlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  Fc2LivePlaybackProvider({required this.site});

  /// The site this capability serves.
  final Fc2LiveSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required LiveRoom room}) async {
    try {
      return right(await site.qualitiesOf(room.roomId));
    } on Fc2LiveFailure catch (failure) {
      return left(failure.toLiveSiteError(fc2LiveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: fc2LiveSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required LiveRoom room, LivePlayQuality? quality}) async {
    try {
      return right(await site.linesOf(room.roomId, quality: quality));
    } on Fc2LiveFailure catch (failure) {
      return left(failure.toLiveSiteError(fc2LiveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: fc2LiveSiteId, message: '$error', cause: error));
    }
  }
}
