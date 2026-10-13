import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/live_play_quality/live_play_quality.dart';

/// The stream qualities a room offers and the playable lines behind them.
///
/// This reports them; it does not open a player, choose an engine, retry, fall
/// back between lines or manage recovery — those belong to `live_playback` and
/// the application layer. A line describes itself (its URL, headers, container
/// format and renewal lease), so the player needs no per-platform code.
abstract interface class LivePlaybackProvider implements LiveSiteCapability {
  /// The qualities [roomId] offers, in the platform's order. A left names why
  /// they could not be read.
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required String roomId});

  /// The playable lines for [roomId] at [quality] (the default quality when it
  /// is null). A short-lived URL is never stored back as permanent room
  /// metadata; its [LivePlayLine.lease] says when to re-resolve.
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required String roomId, LivePlayQuality? quality});
}
