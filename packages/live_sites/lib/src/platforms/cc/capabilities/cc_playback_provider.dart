import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_plan_resolver.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/play/live_playback_plan/live_playback_plan.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/cc/cc_manifest.dart';
import 'package:live_sites/src/platforms/cc/cc_site.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// CC's playback: the real tiers of `video_play_url`, and 3.x's redirect
/// playlist as the fallback when the room carries its tier list.
///
/// The play URLs are signed and expire (`auth_key`), so each line carries
/// the lease of its key; an expired URL refuses new connections only, so an
/// established connection keeps flowing. An anchor who is not broadcasting
/// says stream-unavailable, never an empty list.
final class CcPlaybackProvider implements LivePlaybackProvider, LivePlaybackPlanResolver {
  /// Serves [site].
  CcPlaybackProvider({required this.site});

  /// The site this capability serves.
  final CcSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required LiveRoom room}) async {
    try {
      return right(await site.qualitiesOf(room.roomId));
    } on CcFailure catch (failure) {
      return left(failure.toLiveSiteError(ccSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: ccSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required LiveRoom room, LivePlayQuality? quality}) async {
    try {
      return right(await site.linesOf(room.roomId, quality: quality));
    } on CcFailure catch (failure) {
      return left(failure.toLiveSiteError(ccSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: ccSiteId, message: '$error', cause: error));
    }
  }

  /// The plan for [room]: its lines plus the tier `video_play_url` says it
  /// played (`vbrname_sel`). The 3.x fallback tier list confirms nothing.
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
    } on CcFailure catch (failure) {
      return left(failure.toLiveSiteError(ccSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: ccSiteId, message: '$error', cause: error));
    }
  }
}
