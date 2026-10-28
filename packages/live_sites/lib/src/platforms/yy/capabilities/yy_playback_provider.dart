import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_plan_resolver.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/play/live_playback_plan/live_playback_plan.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_failure.dart';
import 'package:live_sites/src/platforms/yy/yy_manifest.dart';
import 'package:live_sites/src/platforms/yy/yy_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// YY's playback: the qualities of the anonymous mobile HLS route by default
/// (`流畅 · 360p`, `高清 · 720p`), stream-manager's FLV qualities standing in;
/// [YySite.flvFirst] turns the order round.
///
/// A mobile quality's lines come from the mobile route, or — when it has
/// nothing — from stream-manager at the same tier, without confirming the
/// quality. A stream-manager quality's lines carry every CDN line its stream
/// sits on (one extra request per extra line), and every FLV URL carries the
/// lease of its `t` signature. A channel with neither route is
/// content-unavailable, never an empty list.
final class YyPlaybackProvider implements LivePlaybackProvider, LivePlaybackPlanResolver {
  /// Serves [site].
  YyPlaybackProvider({required this.site});

  /// The site this capability serves.
  final YySite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required LiveRoom room}) async {
    try {
      return right(await site.qualitiesOf(room.roomId));
    } on YyFailure catch (failure) {
      return left(failure.toLiveSiteError(yySiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: yySiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required LiveRoom room, LivePlayQuality? quality}) async {
    try {
      return right(await site.linesOf(room.roomId, quality: quality));
    } on YyFailure catch (failure) {
      return left(failure.toLiveSiteError(yySiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: yySiteId, message: '$error', cause: error));
    }
  }

  /// The plan for [room]: stream-manager may serve another gear than asked;
  /// a mobile rate is served as asked. A route standing in for another
  /// (`qualityUnconfirmed`) names no applied quality.
  @override
  Future<Either<LiveSiteError, LivePlaybackPlan>> resolvePlan({
    required LiveRoom room,
    LivePlayQuality? quality,
  }) async {
    try {
      final plan = await site.planOf(room.roomId, quality: quality);
      return right(
        LivePlaybackPlan.of(
          lines: plan.lines,
          appliedQuality: plan.appliedQuality,
          qualityUnconfirmed: plan.unconfirmed,
        ),
      );
    } on YyFailure catch (failure) {
      return left(failure.toLiveSiteError(yySiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: yySiteId, message: '$error', cause: error));
    }
  }
}
