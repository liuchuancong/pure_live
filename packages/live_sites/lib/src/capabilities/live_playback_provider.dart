import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/live_stream/live_stream.dart';

/// Resolves a platform-specific playable source.
///
/// This reports the source; it does not open a player, choose an engine, retry,
/// fall back between lines or manage recovery — those belong to `live_playback`
/// and the application layer.
abstract interface class LivePlaybackProvider implements LiveSiteCapability {
  /// Resolves a playable stream for [roomId], optionally at a [quality] and a
  /// [lineId]. A left names why resolution failed; an empty or short-lived URL
  /// is never stored back as permanent room metadata.
  Future<Either<LiveSiteError, LiveStream>> resolveStream({required String roomId, String? quality, String? lineId});
}
